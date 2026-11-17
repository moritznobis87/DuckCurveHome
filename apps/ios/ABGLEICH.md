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
| davon erledigt | **26** |
| offen | **141** |

## Erledigt

- **`/` · 10 von 10 Punkten** (17.11.) – die vier Kacheln kommen aus `Tageskacheln` im Kern
  (Autarkie, bezahltes Geld, Mittelpreis, erwartete Wärme thermisch, günstigste Stunde mit
  Uhrzeit, der Hinweis auf die Börse um 13 Uhr), die Tagesbilanz wird auch für heute geholt und
  alle fünf Minuten erneuert, am Telefon steht der ``Ausblick`` statt dreier Uhrzeiten, und die
  Warnung des Planers steht unter den Planzeilen.
- **`/waerme/fahrplan` · 16 von 16 Punkten** (17.11.) – acht Flächen über dem ganzen Horizont
  statt einer über 24 Stunden, mit allem Gemessenen (PV, Leistung der Wärmepumpe, Anforderung),
  Warmwasser im Bedarf, Pufferverlauf mit Decke und Reserve, vier unterscheidbaren Zuständen,
  dem Ofen, den Preisfenstern im Bild und Hinweisen in leeren Flächen; die sieben Kacheln der
  Vorlage; die Entscheidungen statt 32 Zeilen „aus"; und statt des Hinweisfensters eine
  Auskunft, die der Finger steuert (Außentemperatur, COP, Prognosefehler, Zerlegung des
  Bedarfs). Dazu zwei Fehler aus den Screenshots: die festverdrahtete Preisachse bis 40 ct und
  die fehlende Tagesangabe an Uhrzeiten im Zweitagehorizont.

## Zwei Läufe, zwei Güten

Die Liste entstand in zwei Durchgängen, und sie sind **nicht gleich belastbar**:

- **Die 12 Wärmeseiten** (zweiter Lauf) tragen zu jedem Punkt die Vorlage mit Datei und Zeile
  und die Swift-Datei, in die es gehört. Damit lässt sich bauen, ohne zu suchen.
- **Die übrigen 15 Seiten** (erster Lauf) haben das nicht: dort starb die Prüfstufe an einer
  Nutzungsgrenze, und die Einträge sind die Behauptung je eines Lesers, ohne Zeilenangabe.
  Vor dem Bauen gehört jeder dieser Punkte am Code nachgesehen; erfahrungsgemäß ist ein Teil
  davon keine Lücke, sondern eine andere Gliederung oder ein anderer Name.

**Keiner der Punkte beider Läufe ist bisher umgesetzt.** Was schon gebaut wurde – die
Zeichnung der Wärmepumpe, der aufrechte Puffer, die Rahmung des Hausmodells – stand nicht in
dieser Liste, sondern kam aus Screenshots vom Gerät.

## Die Punkte, nach Seite

### `/geld`  ·  8 Punkte, davon 3 spürbar

- **spürbar** · endpunkt — Die Webseite holt zusaetzlich /energy/heat und rechnet die Pelletkosten in "Bezahlt" ein, zeigt sie als eigene Zeile der Aufstellung mit Menge in kg und haengt den Pellet-Hinweis an die Methode an; die App fragt den Endpunkt gar nicht ab, Pellets kommen auf der Kostenseite nicht vor.
  - Web: `apps/web/src/components/reports/CostReport.tsx:62,66,112,210,236`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift - KostenSeite holt nur energieUebersicht und energieVerschiebung (Z. 13-16), kein energieWaerme; "Pellet" steht in der ganzen Datei nicht.`
- **spürbar** · kennzahl — Die Webseite zeigt die Kennzahl "Gespart" (pv_direct_savings_eur + battery_net_eur) und darunter die Karte "Woraus die Ersparnis besteht" mit zwei Balken (Sonne direkt genutzt, Speicher statt Netz netto); in der App gibt es weder die Summe noch die Aufteilung - dort heisst "gespart" nur die Ersparnis des Vergleichslaufs, eine andere Groesse.
  - Web: `apps/web/src/components/reports/CostReport.tsx:69,114,124-148`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift - weder pvDirectSavingsEur noch batteryNetEur werden in KostenSeite benutzt (Kacheln Z. 95-118, Karten Z. 22-78); die Felder gibt es im Modell (Schema.swift:3014,3022).`
- **spürbar** · abschnitt — Die Webseite hat die Karte "Aufstellung": je Posten Menge, Durchschnittspreis in ct/kWh, Betrag und ein Verweis auf die Herkunftsseite - Netzstrom Haushalt, Waermepumpe, Wallbox, Speichergeraet, Pellets, Einspeisung sowie die entgangene Verguetung. Die App zeigt von diesen Posten nur eine Kachel "Waermepumpe" in Euro; Haushalt, Wallbox, Speichergeraet und die entgangene Verguetung fehlen ganz, ebenso Menge und ct/kWh je Posten.
  - Web: `apps/web/src/components/reports/CostReport.tsx:193-223 (Zeilen 206-212)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift - KostenSeite benutzt evCostEur, batteryDeviceCostEur, heatPumpGridKwh, evGridKwh, batteryDeviceGridKwh und die *OpportunityEur-Felder nirgends; nach der Verschiebungskarte folgt nur das Balkenbild "Nach Zeitraum" (Z. 56-77) und die Methode.`
- **mittel** · kennzahl — Die Webseite nennt zum Vergleichslauf, wie belastbar er ist: wie viele der verschobenen kWh von wie vielen kWh Waermestrom ueberhaupt stammen, wie viele Tage gerechnet wurden und wie viele ohne Aussage blieben - und sie ersetzt die Zahl durch "Fuer diesen Zeitraum reicht es nicht fuer eine Aussage", wenn days_used 0 ist. Die App zeigt die Eurobetraege und shiftedKwh, aber keine Tageszahlen, keinen Bezug auf heatPumpKwh und keinen Hinweis, wenn kein Tag gerechnet werden konnte.
  - Web: `apps/web/src/components/reports/CostReport.tsx:162-171`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:23-55 - die Karte "Was der Preisblick gebracht hat" zeigt actualEur, naiveEur, savingEur, savingCtPerKwh, shiftedKwh; daysUsed, daysSkipped und heatPumpKwh werden in der Datei nicht gelesen, die Karte erscheint auch bei daysUsed = 0.`
- **mittel** · abschnitt — Die Webseite stellt unten die Kennzahlen Bezahlt, Bekommen, Gespart, Netzbezug und Durchschnittspreis fuer Tag, Woche, Monat und Jahr des Ankertags nebeneinander (vier gleichzeitig geladene Abfragen). Die App zeigt immer nur die eine gewaehlte Spanne; einen solchen Spannenvergleich gibt es auf der Kostenseite nicht.
  - Web: `apps/web/src/components/reports/CostReport.tsx:64,225-235 (apps/web/src/components/reports/PeriodStrip.tsx:32-93)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift - KostenSeite laedt genau einen Zeitraum (Berichtsseite, Z. 11-16); in der App gibt es ueberhaupt kein Gegenstueck zu PeriodStrip.`
- **mittel** · zustand — Unter der Webseite steht die Datengueteangabe: "Datenabdeckung NN %" bzw. "noch keine Messdaten im Zeitraum" und "Aufzeichnung seit TT.MM.JJJJ". Die App zeigt aus demselben meta-Objekt nur estimatedNoteDe; Abdeckung und Aufzeichnungsbeginn fehlen.
  - Web: `apps/web/src/components/reports/CostReport.tsx:236 (CoverageNote, apps/web/src/components/reports/ReportShell.tsx:163-174)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:79-86 - Methode([...]) enthaelt nur methodDe, skippedDe, estimatedNoteDe und die Annahmen; meta.coverage und meta.dataSince werden nicht gezeigt (in StromSeite.swift:25 tut die App das sehr wohl).`
- **klein** · bedienung — Die Zeitraumleiste der Webseite hat neben Zurueck/Weiter eine Schaltflaeche "heute", die vom durchblaetterten Zeitraum direkt auf den laufenden zurueckspringt. Die App bietet nur Schrittweise vor und zurueck.
  - Web: `apps/web/src/components/reports/ReportShell.tsx:116 (onToday, von CostReport.tsx:107 uebergeben)`
  - iOS: `apps/ios/DuckCurveHome/App/Seitenwahl.swift:195-228 - Zeitraumleiste.blaettern hat nur "Zurueck" und "Vorwaerts"; kein Sprung auf den laufenden Zeitraum.`
- **klein** · kennzahl — Die Webseite zeigt die Kachel "Energie je Tag": bezahlt minus bekommen, geteilt durch die bewerteten Tage des Zeitraums, mit Angabe wie viele Tage bewertet wurden. In der App gibt es diese Kennzahl nicht.
  - Web: `apps/web/src/components/reports/CostReport.tsx:70-71,115`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:95-118 - kennzahlen(...) liefert gespart, unterm Strich, Bezug, Einspeisung, Waermepumpe, mittlerer Bezugspreis; totals.minutes wird nicht ausgewertet.`

### `/haus`  ·  7 Punkte, davon 1 spürbar

- **spürbar** · abschnitt — Die Webseite zeigt neben dem Haus einen Block "Fenster und Türen" mit der Zahl der offenen Kontakte, einem Satz dazu ("alles zu" / "Küche und 2 weitere") und aufgeklappt jedem Kontakt mit Namen, Raum, Zustand (offen/zu/keine Meldung) und "offen seit 12 min"; auf der iOS-Seite gibt es weder Zahl noch Liste - offene Kontakte sind nur als leuchtende Striche im Modell zu sehen.
  - Web: `apps/web/src/components/house/Konsole.tsx:186-224 (Block `kontakte`, `offeneKontakte.length`, `offenSatz`, Liste mit `seitText(k.observed_at, nowMs)`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift:23-38 - die Seite besteht aus Kopf, Störung, Alarmkarte und entweder Raumliste (87-106) oder Modell (130-160); die Kontakte gehen allein als Wörterbuch an `Glasmodell` (139), das sie in apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift:197-225 nur als Striche zeichnet. Eine Zahl, ein Zustandswort oder ein Alter steht nirgends in der Datei (nur im Vorlesetext, Glasmodell.swift:266-276).`
- **mittel** · abschnitt — Die Webseite zeigt neben dem Haus einen Pufferblock: Ladestand in Prozent, die vier Schichttemperaturen mit Alter ("vor 2 d", wenn ein Fühler nicht frisch ist), die nutzbare Energie von der Kapazität in kWh, das Zustandswort mit dem freien Platz ("noch 23 % Platz") und unten Rechenweg und Volumen in Litern; die iOS-Seite zeigt zum Puffer nichts.
  - Web: `apps/web/src/components/house/Konsole.tsx:226-277 (`live.pufferSoc`, `schichtZeilen`, `state.buffer.usable_energy_kwh` von `capacity_kwh`, `statusWort`, `headroom_soc`, `methodeText`, `volume_liters`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift - vollständig gelesen: kein Puffer. `usableEnergy`, `headroom` oder `capacityKwh` kommen in apps/ios/DuckCurveHome gar nicht vor (einzige Fundstelle ist der Grundtext "im Puffer ist kein Platz" in Bausteine/Blaetter.swift:497).`
- **mittel** · diagramm — Die Webseite zeigt neben dem Haus einen Wärmepumpenblock mit der Tageskurve der Leistung als kleines Diagramm und dazu Strom heute, Laufzeit, Starts, dem Anforderungskontakt, der Begründung der letzten Entscheidung und der Betriebsart; die iOS-Seite zeigt zur Wärmepumpe nichts.
  - Web: `apps/web/src/components/house/Konsole.tsx:279-306 (`<Tageskurve werte={verdichte(history.map((p) => p.hp), 96)} ...>` aus :111-131, Zeilen "heute", "Laufzeit", "Starts", "Anforderung", `decision.explanation_de`, "Betrieb")`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift:23-38 und 130-160 - weder `heatPump` noch `decision` noch ein `Chart` erscheinen in der Datei; die Seite holt nur `raeume()` und `haus()` (164-174).`
- **mittel** · bedienung — Im Modell der Webseite öffnet ein Tippen auf einen Raum eine Tafel mit großer Temperatur, Ziel, Heizkreis, den Fenstern und Türen genau dieses Raums ("keine Kontakte in diesem Raum") und einem Knopf "Sollwert stellen"; das iOS-Modell lässt sich nur drehen, Räume sind nicht antippbar.
  - Web: `apps/web/src/components/house/HouseReport.tsx:295-343 (Tafel `haus-panel` mit `fokusWerte`, `fokusKontakte`, Knopf "Sollwert stellen") in Verbindung mit `onFokus: setFokus` (:142)`
  - iOS: `apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift:38-57 - die einzige Gestik ist `DragGesture` zum Drehen; es gibt kein Tippen, keinen Fokus und keine Raumtafel. In apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift wird das Raumblatt nur aus der Liste geöffnet (Zeile 95-97), und das Raumblatt selbst nennt keine Fenster-/Türkontakte (Bausteine/Blaetter.swift:70-97).`
- **klein** · abschnitt — Die Webseite zeigt einen Block "Heizkreise" mit der Zahl der offenen Kreise, der Liste der betroffenen Räume mit Ventilwort und Temperatur und dem Satz zum Raum, der alle Kreise offen hat und trotzdem unter dem Ziel liegt (er bestimmt die nötige Vorlauftemperatur mit); auf der iOS-Seite stehen Ventilstände nur je Raumzeile, Zahl und dieser Hinweis fehlen.
  - Web: `apps/web/src/components/house/Konsole.tsx:308-351 (`live.kreiseOffen`, `kreisZeilen`, `anDerGrenze`-Satz)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift:228-239 - `Raumzeile.unterzeile` nennt "Ventil offen"/"Ventil 40 %" je Raum; eine Summe über die offenen Kreise oder ein Satz über den bestimmenden Raum steht in der Datei nicht.`
- **klein** · bedienung — Im Modell der Webseite wählt man das Geschoss (Alle / Erdgeschoss / Obergeschoss), und unter dem Bild steht eine Legende (kalt-warm, "gelb: unter Ziel · tippen: Raum"); das iOS-Modell zeichnet immer alle Geschosse übereinander und hat keine Legende.
  - Web: `apps/web/src/components/house/HouseReport.tsx:232-243 (Geschoss-Reiter mit `waehleDeck`) und :289-294 (Legende)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift:130-160 - `modell` übergibt den ganzen Plan an `Glasmodell`, ohne Auswahl; apps/ios/DuckCurveHome/Haus3D/Glasmodell.swift:112-121 zeichnet in `zeichne` stets alle `plan.decks`. Eine Legende steht in keiner der beiden Dateien.`
- **klein** · abschnitt — Die Webseite nennt im Kopf, welcher Hausplan gezeigt wird und woher er kommt ("Hausplan · von der Brücke"), und setzt unter das Modell die Anmerkung des Plans (`note_de`); die iOS-Seite zeigt im Kopf nur "Stand hh:mm".
  - Web: `apps/web/src/components/house/HouseReport.tsx:219 (`kicker={plan ? `${plan.name || "Hausplan"} · ${house?.source_de ?? ""}` : "Hausplan"}`) und :354 (`{plan?.note_de ...}`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Haus/HausSeite.swift:65-83 - `kopf` enthält Ansichtswahl und `Stand \(Formate.hhmm(at))`; `plan.name`, `sourceDe` und `noteDe` kommen in der Datei nicht vor (nur `errorDe`/`present` im Leerfall, 149-158).`

### `/strom`  ·  4 Punkte

- **mittel** · kennzahl — Die Webseite zeigt den Netzbezug als Geldbetrag (import_cost_eur) als eigene Kachel neben den Kilowattstunden; die iOS-Seite nennt den Bezug nur in kWh und gar keinen Euro-Betrag.
  - Web: `apps/web/src/components/reports/HouseReport.tsx:51-58`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:30-48 (kennzahlen(_:) der StromSeite: Autarkie, Sonne, Netz, Einspeisung, Haus, Eigenverbrauch - kein Geldwert; importCostEur kommt in der ganzen Datei nicht vor)`
- **mittel** · abschnitt — Die Webseite hat den Abschnitt "Strom im Überblick": dieselben Größen (Verbrauch, Autarkie, Netzkosten, Einspeiseerlös) für Tag, Woche, Monat und Jahr des Ankertags nebeneinander, vier Abfragen auf einmal. Die iOS-Seite kann nur die eine gewählte Spanne zeigen; der Einspeiseerlös steht dort überhaupt nicht.
  - Web: `apps/web/src/components/reports/HouseReport.tsx:72-81 (PeriodStrip) mit apps/web/src/components/reports/useReport.ts:55-76 (useMultiPeriod)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:9-28 (StromSeite holt nur energieUebersicht für den aktuellen Zeitraum; kein Mehrspannen-Abschnitt, und in apps/ios/DuckCurveHome/Seiten/Bericht.swift gibt es kein Gegenstück zu PeriodStrip)`
- **mittel** · zustand — Die Webseite zeigt unter jeder Auswertung die Datengüte des Zeitraums: "Datenabdeckung 93 %" bzw. "noch keine Messdaten im Zeitraum" (meta.coverage). Die iOS-Seite druckt nur estimatedNoteDe und dataSince, die Abdeckung nie - obwohl das Feld im Modell liegt.
  - Web: `apps/web/src/components/reports/ReportShell.tsx:163-174 (CoverageNote), aufgerufen in HouseReport.tsx:82`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:23-26 (Methode([estimatedNoteDe, dataSince])); coverage steckt in apps/ios/DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:2836, wird aber in keiner Energie-Seite gelesen`
- **klein** · kennzahl — Die Webseite zeigt Wärmepumpe, Wallbox und Haushalt (Rest) als eigene Kacheln mit Summe in kWh und Anteil am Hausverbrauch ("45 % des Verbrauchs"). Auf der iOS-Seite kommen die drei nur als Balkenreihen je Zeitschritt vor - keine Summe, kein Anteil, und in der Tabelle "Die Zahlen" fehlen die Spalten.
  - Web: `apps/web/src/components/reports/HouseReport.tsx:46-48 mit share() in Zeile 38`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:30-48 und 86-99 (Tabelle: Sonne, Haus, Bezug, Einspeisung)`

### `/system`  ·  6 Punkte, davon 4 spürbar

- **spürbar** · diagramm — Die Webseite zeichnet den Tag im 15-Minuten-Raster (Ist, Day-ahead und der juengste korrigierte Lauf) und laesst zwischen Heute und Gestern umschalten; die iOS-Seite zeigt keinen Tagesverlauf und wertet b.today/b.yesterday mit ihren Punkten ueberhaupt nicht aus.
  - Web: `apps/web/src/components/forecast/ForecastPage.tsx:42-87 (dayOption mit actual/ahead/corrected) und :267-293 (Karte mit Heute/Gestern-Umschalter)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:346-443 - PrognoseSeite liest nur stageDe, correctionActive, runsKept, horizons, daily und notesDe; today/yesterday (ForecastDayOut.points mit actualKw/dayAheadKw/correctedKw) kommen in der ganzen Datei nicht vor, obwohl die Datei ab Zeile 86 Swift Charts verwendet`
- **spürbar** · abschnitt — Die Webseite listet die Prognosequellen mit Gewicht, MAE 7 Tage und Status (aktiv/aus) sowie den Gesamtwert Ist/Prognose; in der App fehlt die Quellenliste vollstaendig.
  - Web: `apps/web/src/components/forecast/ForecastPage.tsx:342-363 (Tabelle Quelle/Gewicht/MAE 7 d/Status) und :246 (Kopfzeile mit sources[0].label_de)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:346-443 - b.sources wird nirgends gelesen; das Feld existiert im Modell (DuckCurveKit/Sources/DuckCurveKit/Modelle/Schema.swift:3356, SourceOut mit weight/mae7dKw/active)`
- **spürbar** · abschnitt — Die Webseite zeigt die gelernten Korrekturfaktoren nach Sonnenhoehe (Faktor heute, gestern, letztes Ist/Prognose, Lerntage je Klasse) samt Lerntagen, Halbwertszeit und Tagesabschluss; die App sagt nur ja/nein zu "Korrektur aktiv" und zeigt vom Korrektor sonst nichts.
  - Web: `apps/web/src/components/forecast/ForecastPage.tsx:142-180 (factorOption ueber ev.corrector.bins) und :314-322 (Karte "Korrekturfaktoren nach Sonnenhoehe" mit days_learned und half_life_days)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:364-372 - nur Zeile "Korrektur aktiv"; b.corrector (CorrectorState mit bins, kGlobal, daysLearned, halfLifeDays, updatedOn, Schema.swift) wird in der Datei nie benutzt`
- **spürbar** · kennzahl — Im Rueckblick zeigt die Webseite je Reihe den Fehler nach Vorlaufklasse - mittlerer Fehler als Balken, der Rand (95 %) als Punkt darueber, dazu die Zahl der Paare und den Bias; die App zeigt je Reihe nur eine Gesamtzahl und laesst die ganze Aufschluesselung nach Vorlauf samt p95 weg.
  - Web: `apps/web/src/components/forecast/Rueckblick.tsx:36-99 (mae und p95 je je_vorlauf, n Paare) und :182-198 (Karte je Reihe mit Bias und Paarzahl)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:422-437 - Tabelle mit gesamt.mae, Einheit und Laeufe; reihe.jeVorlauf und wertung.p95/bias/n (Schema.swift, VorlaufOut/Wertung) werden nicht gelesen`
- **mittel** · kennzahl — Den systematischen Fehler (Bias) zeigt die Webseite an drei Stellen - je Tag, je Vorlauf-Horizont und als Mittel der letzten 7 Tage; in der App kommt Bias auf der Prognoseseite nicht vor, dort steht nur der Betrag des Fehlers.
  - Web: `apps/web/src/components/forecast/ForecastPage.tsx:103 und :129 (Bias in den Auswertungen je Tag und je Horizont), :240 und :365 ("Bias 7 Tage")`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:375-414 - die Spalten der Horizont- und Tagestabelle sind maeKw, energyForecastKwh, energyActualKwh und energyErrorPct; biasKw (ForecastScore, Schema.swift) wird nicht ausgegeben`
- **klein** · bedienung — Die Webseite laesst den Zeitraum des Rueckblicks waehlen (3, 7, 14, 30 Tage); die App holt fest 7 Tage, ohne Wahlmoeglichkeit.
  - Web: `apps/web/src/components/forecast/Rueckblick.tsx:167-178 (Knopfreihe 3/7/14/30 d, setTage)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:449 - prognoseVerlauf(tage: 7) fest verdrahtet; die Seite baut keine Tagewahl ein, obwohl der Baustein Tagewahl in derselben Datei (Zeile 599) verwendet wird`

### `/waerme`  ·  14 Punkte, davon 5 spürbar

- **spürbar** · endpunkt — Die Webseite holt drei Antworten: /energy/waermebilanz (Leitquelle fuer Waermemenge, Arbeitszahl, Waermepreis), /energy/heat (nur noch Strom nach Herkunft, Taktung, Ofen) und /energy/shift. Die iOS-Seite holt ausschliesslich api.energieWaerme (/energy/heat). Damit fehlt auf der Seite alles, was nur in HeatBalanceOut steht: totals.producedKwh / drawKwh / lossKwh / residualKwh / copMean, cost (HeatCostOut), ventilation (VentilationOut), params (HeatParamsOut), series und buckets. api.waermebilanz und api.energieVerschiebung sind im Client schon da (apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:192 und :184) - sie werden hier nur nicht gerufen. (Die Bilanz selbst zeigt die App unter /waerme/bilanz; auf dieser Seite soll sie aber neben Strom, Taktung und Ofen stehen.)
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:91-95`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **spürbar** · abschnitt — Karte "Was die Waerme gekostet hat": als Kernzahl cost.heat_pump_ct_per_kwh in "ct je kWh Waerme", darunter fuenf Zeilen - "Waermepumpe: bezahlter Netzstrom" (heat_pump_paid_eur, Euro), "Waermepumpe: entgangene Verguetung" (heat_pump_opportunity_eur), "Pellets: verbrannte Menge" (stove_kg, 1 Stelle, kg), "Pellets: Wert zum hinterlegten Preis" (stove_eur), "Ofen: je kWh Waerme" (stove_ct_per_kwh, ct) - und als Fussnote cost.cheaper_de. In der App kommt auf dieser Seite kein Eurobetrag und kein Waermepreis vor; nur der Ofen hat "Pelletkosten" aus StoveOut.pelletEur.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:214-225`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **spürbar** · abschnitt — Karte "Hat sich das Verschieben gelohnt?" (rechts "geschaetzt") aus /energy/shift: Kernzahl ist der Betrag von saving_eur, die Unterzeile sagt je nach Vorzeichen "gespart gegenueber einem Lauf ohne Preisblick" oder "mehr bezahlt als ohne Preisblick"; darunter bei days_used > 0 drei Zeilen - "in andere Stunden verschoben" (shifted_kwh von heat_pump_kwh), "je verschobener kWh" (saving_ct_per_kwh), "gerechnete Tage" (days_used); bei days_used == 0 stattdessen skipped_de bzw. der Ersatzsatz "Dafuer braucht es einen Tag mit genug gemessenen Stunden und laufender Waermepumpe." Dazu die Verweise auf /geld (mit Zeitraum) und, am Tag, auf /waerme/nachbetrachtung?day=. Auf der iOS-Seite fehlt die Karte ganz.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:248-273`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **spürbar** · diagramm — Am Tag die Karte "Tagesverlauf" (Kopf rechts resolution_de) mit dem Bilanzdiagramm aus bilanz.series: oben in kW drei gestapelte Flaechen (Waermepumpe, Ofen (Wasser), Ofen (Raum)) plus die Linien Entnahme und "Verlust an den Raum", unten in einer zweiten Flaeche der Pufferinhalt in kWh; Luecken werden nicht ueberbrueckt (connectNulls false). Leerfall: "Fuer diesen Tag liegen keine Minutenwerte vor." Die iOS-Seite hat auf /waerme ueberhaupt kein Diagramm, und b.summary.buckets wie HeatBalanceOut.series bleiben ungenutzt.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:170-180 mit apps/web/src/components/reports/charts.ts:793-880`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **spürbar** · diagramm — Karte "Pufferspeicher" (nur am Tag, nur wenn buffer_series Werte hat; Kopf rechts "Temperaturen in vier Hoehen · Leistung der Waermepumpe"): oben die vier Schichttemperaturen buffer_temp_top_c / mid_top / mid_bottom / bottom_c als Linien auf fester Skala 20-70 °C, unten als Treppenflaeche heat_pump_power_kw, und als hinterlegte Baender die Brennphasen des Ofens (zusammenhaengende Abschnitte mit stove_running wahr, Legendeneintrag "Ofen brennt"). Genau daran liest man ab, ob eine Temperatursteigung vom Ofen kam. HeatReportOut.bufferSeries wird in der App nirgends ausgewertet.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:197-204 mit apps/web/src/components/reports/charts.ts:99-145`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **mittel** · diagramm — Karte "Strom der Waermepumpe nach Herkunft": je Zeitstueck aus summary.buckets ein gestapelter Balken aus heat_pump_pv_kwh ("aus PV"), heat_pump_battery_kwh ("aus Batterie") und heat_pump_grid_kwh ("aus Netz"), mit Farblegende im Kartenkopf. Die App zeigt diese Aufteilung auf keiner Waermeseite - weder als Diagramm noch als Zahl; summary.buckets bleibt ungenutzt.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:35-39 und 205-210`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **mittel** · abschnitt — Karte "Bei offenem Fenster" (Kopf rechts "geschaetzt, nach offenen Heizkreisen verteilt"), nur wenn ventilation.kwh > 0,01 oder open_minutes > 0: Kernzahl ventilation.kwh "kWh in Raeume mit offenem Fenster", rechts "NN min offen" und bei share >= 0,01 "· NN % der Entnahme"; darunter eine Tabelle je Raum mit Raum, "Fenster offen" (open_minutes), "davon geheizt" (heating_minutes) und "Waerme" (kWh), dazu ventilation.note_de. In der App fehlt der Abschnitt; VentilationOut wird nirgends ausgewertet.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:310-342`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **mittel** · abschnitt — Abschnitt "Waerme im Zeitraum": dieselben zwoelf Groessen fuer Tag, Woche, Monat und Jahr des Ankertags nebeneinander (vier gleichzeitige Abfragen von /energy/waermebilanz) - Waerme gesamt, Waermepumpe, Ofen ins Wasser, Ofen in den Raum, Entnahme, Verlust, Strom Waermepumpe, Arbeitszahl, nicht zuzuordnen, Strom bezahlt, Pellets kg, Pellets im Wert von. Null gilt dabei als Messung, fehlende Minuten (totals.minutes == 0) als Strich. Die App zeigt immer nur die eine gewaehlte Spanne; einen Spannenvergleich gibt es in Bericht.swift noch gar nicht.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:118-131 und 346, mit apps/web/src/components/reports/PeriodStrip.tsx:32-93 und apps/web/src/components/reports/useReport.ts (useMultiPeriod)`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **mittel** · kennzahl — Drei der sechs Kopfkacheln fehlen: "Bezahlt" (cost.heat_pump_paid_eur in Euro, dazu "NN kWh Netz · Ø NN ct" aus heat_pump_grid_kwh und paid/grid*100), "Waermepreis" (cost.heat_pump_ct_per_kwh in ct/kWh, dazu "Waermepumpe · Ofen NN ct") und "Entnahme" (totals.draw_kwh in kWh, dazu "Heizung und Warmwasser · Verlust NN kWh"). Ausserdem traegt die Webkachel "Strom Waermepumpe" den Zusatz "NN % Sonnenstrom" ((pv+battery)/heat_pump), die App-Kachel "Strom dafuer" nennt den Anteil nicht.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:140-166`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **mittel** · kennzahl — In der Ofenkarte zeigt die Webseite neun Zeilen plus die Leistungsstufen; der App fehlen davon: "davon mit Feuer" (burning_minutes als h:mm), "laengste Phase" (longest_run_min), "Spreizung" (spread_k in K), "Rauchgas max." (fume_temp_max_c in °C), "Betriebsstunden" (operating_hours in h), die Zeile "Leistungsstufen: 1: 0:45 h  2: 1:10 h …" aus minutes_by_level (nach Stufe sortiert) sowie fuel_note_de (nur wenn auger_revolutions gesetzt ist). Auch die Kopfangabe "N Brennphasen" (runs) und note_de stehen dort. Alle Felder liegen in StoveOut.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:279-305`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **klein** · abschnitt — Fuer Woche, Monat und Jahr steht statt des Tagesverlaufs die Karte "Waerme je Tag" bzw. "Waerme je Monat": gestapelte Balken aus bilanz.buckets (Waermepumpe, Ofen (Wasser), Ofen (Raum)) mit Farblegende und Leerhinweis "Fuer diesen Zeitraum liegen keine Werte vor." Die App hat dieses Bild nur auf /waerme/bilanz (WaermebilanzSeite, Karte "Woher die Waerme kam"), auf /waerme nicht.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:182-192`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **klein** · kennzahl — Im Kopf der Taktungskarte steht, auf welcher Datenbasis das Urteil beruht: "NN h bewertet" aus cycling.covered_hours (nur wenn gesetzt). Die App zeigt in der Takt-Karte nur das Urteilswort als Titel; coveredHours liegt in CyclingStats und wird nicht benutzt.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:228`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **klein** · abschnitt — Der letzte Methodenabsatz nennt die geltenden Annahmen mit Zahlen: "Gerechnet wird mit: Kennlinie -7 °C: 2,4 · 2 °C: 3,0 … , gueltig bei NN °C Vorlauf; Puffer NNN l mit NN W/K Verlust (buffer_loss_kw_per_k * 1000); Ofen N,N kW, davon N,N kW ins Wasser; Pellets N,NN kWh/kg zu NNN €/t" - alles aus bilanz.params - samt Verweis auf /waerme/annahmen und dem Satz, dass eine Aenderung auch vergangene Jahre aendert. Die Methodenkarte der App bringt nur die note_de-Saetze des Dienstes, keine Zahl aus HeatParamsOut.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:370-378`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`
- **klein** · zustand — Unter der Auswertung steht die Datenguete als eigene, einklappbare Zeile: "Datenabdeckung NN %" bzw. "noch keine Messdaten im Zeitraum" und "Aufzeichnung seit TT.MM.JJJJ" aus summary.meta.coverage und data_since. Die App druckt aus demselben meta-Objekt nur estimatedNoteDe.
  - Vorlage: `apps/web/src/components/reports/HeatOverview.tsx:348 mit apps/web/src/components/reports/ReportShell.tsx:163-174`
  - bauen in: `apps/ios/DuckCurveHome/Seiten/Energie/WaermeSeite.swift`

### `/geld/pv-abrechnung`  ·  6 Punkte, davon 1 spürbar

- **spürbar** · diagramm — Die Webseite hat das Diagramm "Erloes und Wertabgabe": je Zeitraumstueck zwei Balken, Einspeiseverguetung netto und Wert des Eigenverbrauchs netto, mit Leerhinweis "Fuer diesen Zeitraum liegen keine bewerteten Stunden vor". Die App zeigt auf der PV-Abrechnung ueberhaupt kein Diagramm.
  - Web: `apps/web/src/components/reports/PvAccounting.tsx:64-74,100-105`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:124-199 - PvAbrechnungSeite besteht aus Kachelfeld, zwei Karten mit Zeilen, einer Tabelle und der Methode; Balkenbild wird nicht benutzt.`
- **mittel** · kennzahl — In der Aufstellung der Webseite stehen je Zeitraumstueck sieben Spalten, darunter "USt darauf (erhalten)" aus der Einspeisung und "Wertabgabe netto" des Eigenverbrauchs. Die Tabelle der App hat nur vier Spalten; die Umsatzsteuer der Einspeisung und der Nettowert der Wertabgabe fehlen je Zeitraum (sie stehen nur als Gesamtsumme in den Karten).
  - Web: `apps/web/src/components/reports/PvAccounting.tsx:29-37 (Spalten "USt darauf · erhalten" Z. 32, "Wertabgabe · netto" Z. 34),122-131`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:155-180 - Tabelle mit den Spalten eingespeist, Verguetung, Eigenverbrauch, USt. zu zahlen; exportVatEur und selfValueNetEur werden je bucket nicht gezeigt.`
- **mittel** · abschnitt — Unter der Webseite steht der Methodensatz des Dienstes (meta.method_de) samt "Datenabdeckung NN %" bzw. "Fuer diesen Zeitraum liegen keine Messdaten vor". Die Methodenkarte der App bringt nur Steuersatz, Schaetzanteil und den Steuerberatungs-Vorbehalt; method_de und die Abdeckung fehlen.
  - Web: `apps/web/src/components/reports/PvAccounting.tsx:163-172`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:182-198 - Methode([...]) ohne b.meta.methodDe und ohne b.meta.coverage (beide im Modell: Schema.swift:6363-6371).`
- **mittel** · abschnitt — Die Webseite zeigt dieselben Kennzahlen (Einspeisung, Verguetung netto, Eigenverbrauch, Wert netto, Umsatzsteuer) zusaetzlich fuer Tag, Woche, Monat und Jahr des Ankertags nebeneinander. Die App zeigt nur die gewaehlte Spanne.
  - Web: `apps/web/src/components/reports/PvAccounting.tsx:56,151-161`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:126-128 - PvAbrechnungSeite laedt genau einen Zeitraum; ein Spannenvergleich existiert in der App nicht.`
- **klein** · kennzahl — Die Aufstellung der Webseite schliesst mit einer hervorgehobenen Summenzeile ueber alle Spalten und dem Hinweis, dass die Summe aus ungerundeten Stundenwerten stammt und die Addition der Zeilen um Cent abweichen kann. Die Tabelle der App hat keine Summenzeile.
  - Web: `apps/web/src/components/reports/PvAccounting.tsx:77,132-148`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:154-181 - die Tabelle enthaelt nur die buckets, keine Zeile aus b.totals.`
- **klein** · kennzahl — Die Webseite nennt zum Eigenverbrauch den mittleren Wert je Kilowattstunde (self_ct_kwh, "netto, Ø x,xx ct/kWh"). Die App zeigt diesen Satz nicht.
  - Web: `apps/web/src/components/reports/PvAccounting.tsx:96`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/GeldSeiten.swift:139-153,201-222 - weder die Karte "Eigenverbrauch" noch kennzahlen(...) lesen totals.selfCtKwh (Feld vorhanden: Schema.swift:6454).`

### `/geld/rechnungen`  ·  9 Punkte, davon 3 spürbar

- **spürbar** · bedienung — Auf der Webseite kann man eine Tibber-Rechnung als PDF hineinziehen oder auswaehlen - auch mehrere auf einmal -, sie wird geprueft, der Zustand "Rechnung wird geprueft …" angezeigt und pro Datei ein Fehler gemeldet. Die App bietet kein Einlesen; sie verweist im Leerzustand darauf, dass Rechnungen ueber den Dienst hereinkommen, obwohl der API-Client die Pruefung kann.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:54-93,137-159,210-218`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:26-33,185-204 - nur ladeListe/ladeBericht; api.pruefeRechnung (DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:402-408) wird von der Seite nicht aufgerufen, kein Dateiauswahl- oder Ladezustand.`
- **spürbar** · kennzahl — Die Webseite zeigt vier Kennzahlen ueber alle Rechnungen zusammen: Anzahl geprueft (mit Zeitspanne von-bis), Anzahl beanstandet, Summe brutto (ueber x kWh) und mengengewichteter Durchschnittspreis brutto. Die App zeigt Kennzahlen nur zur einzelnen gewaehlten Rechnung, keine Summe ueber den Bestand.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:194-196,219-224`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:34-46,171-183 - die Liste ist eine reine Aufzaehlung, Kachelfeld entsteht erst aus dem Bericht einer gewaehlten Rechnung; ueber `liste` wird nichts summiert.`
- **spürbar** · diagramm — Die Webseite zeigt drei Verlaufsdiagramme ueber alle Rechnungen: abgerechnete Menge gegen eigene Messung, Rechnungsbetrag gestapelt aus Arbeitspreis, Grundgebuehr und Steuer, sowie den Durchschnittspreis brutto Rechnung gegen Messung. Die App hat auf dieser Seite kein Diagramm.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:161-188,229-243`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:21-50,95-142 - die Seite besteht aus Liste, Kachelfeld, Befundkarte, Messkarte, Positionstabelle und Methode; kein Balkenbild oder anderes Diagramm.`
- **mittel** · diagramm — Die Webseite zeigt die Preisbestandteile der gewaehlten Rechnung als Diagramm, nach Gruppe (position.group) geordnet, mit Hinweis "Eine Rechnung in der Liste auswaehlen", wenn keine gewaehlt ist. Die App listet die Positionen nur als Tabelle und laesst das Feld group ungenutzt.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:189-192,244-251`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:121-134 - Tabelle mit ct/kWh und Betrag; $0.group wird nicht gelesen (Feld vorhanden: Schema.swift:4700).`
- **mittel** · kennzahl — Die Webseite nennt zur gewaehlten Rechnung den abgerechneten Zeitraum als Datum von-bis und die Zaehlerstaende am Anfang und Ende samt der Angabe, ob sie abgelesen oder errechnet sind. Die App zeigt nur das Zeitraum-Etikett und das Ausstellungsdatum.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:322-326`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:52-73,171-183 - meterStart, meterEnd, meterEstimated, periodStart und periodEnd werden nirgends gezeigt (Felder vorhanden: Schema.swift:4783-4786).`
- **klein** · kennzahl — Die Webseite sagt zur rechnerischen Pruefung, wie viele Punkte von wie vielen stimmig sind, und schreibt beim Abgleich mit den eigenen Daten "Kein Abgleich moeglich", wenn es dazu keinen Befund gibt. Die App zeigt die Befunde ohne Zaehlung und laesst die Karte ganz weg, wenn keine Befunde da sind.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:307-320`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:98-106 - `if !b.findings.isEmpty` und eine ForEach ueber alle Befunde; keine Quote und kein Hinweis bei fehlendem Abgleich.`
- **klein** · kennzahl — Die Webseite zeigt bei jedem Befund neben Erwartung und Rechnungswert auch die Abweichung mit Vorzeichen. Die App zeigt nur erwartet und auf der Rechnung.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:44`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:155-166 - befund(...) liest f.expected und f.actual, f.delta nicht (Feld vorhanden: Schema.swift:4661).`
- **klein** · bedienung — Die Webseite waehlt beim Oeffnen selbst eine Rechnung aus - die aus ?nr= verlinkte, sonst die neueste -, damit Befunde und Preisbestandteile nicht leer bleiben. In der App bleibt der untere Teil leer, bis man eine Zeile antippt.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:127-135`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:16,44-49 - `gewaehlt` startet als nil, der Bericht wird erst nach einem Tippen geholt; eine Vorauswahl gibt es nicht.`
- **klein** · zustand — Scheitert das Laden einer einzelnen Rechnung, zeigt die Webseite dafuer eine Fehlermeldung. Die App verschluckt den Fehler und laesst die Seite einfach ohne Pruefbericht stehen.
  - Web: `apps/web/src/components/reports/InvoiceCheck.tsx:117-125 (setError bei api.tibberInvoice)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Geld/RechnungenSeite.swift:198-204 - `bericht = try? await haus.api.rechnung(nummer)`, kein Setzen von `fehler`; Stoerung (Z. 23-25) greift nur beim Laden der Liste.`

### `/strom/jahr`  ·  4 Punkte, davon 1 spürbar

- **spürbar** · diagramm — Die Webkarte ist ein Jahr als Tag × Stunde: je Tag alle 24 Stunden, 365 Spalten mal 24 Zeilen (Kicker "365 Tage × 24 Stunden"). Die iOS-Karte liest dieselbe Antwort als Wochen aus sieben Tagen und zeichnet darum nur sieben Felder je Tag - sichtbar sind die Stunden 0 bis 6, die übrigen 17 Stunden jedes Tages fehlen im Bild.
  - Web: `apps/web/src/components/reports/YearMap.tsx:61-71 und apps/web/src/components/reports/charts.ts:447-451 (Schleife h = 0..23); Antwortform in apps/api/src/dch_api/schemas.py:607-620 ("metrics: Kennzahl → [Tag][Stunde 0-23]")`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:160-186 (Raster: HStack über wochen.count, innen ForEach(0..<7) - Index 0-6 der Stundenreihe)`
- **mittel** · bedienung — Auf der Webseite öffnet ein Klick auf ein Feld die Wiedergabe genau dieser Stunde (/waerme/wiedergabe?day=…&t=…), und das Hinweisfenster sagt es auch an. Die Felder der iOS-Karte sind nicht antippbar.
  - Web: `apps/web/src/components/reports/YearMap.tsx:68, 75-84, 127 (onKlick={zurWiedergabe})`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:180-186 (feld(woche:tag:) ist ein RoundedRectangle ohne Geste, zusätzlich accessibilityHidden)`
- **mittel** · diagramm — Für die Kennzahl "Netz" (grid_net_kwh, die Vorgabe der Webseite) benutzt die Webkarte eine zweiseitige Skala: Bezug blau, Einspeisung bernstein, und die Obergrenze ist das 98. Perzentil, damit ein Ausreißer nicht das Jahr einfärbt. Die iOS-Karte hat eine einzige Skala "wenig → viel" und schneidet negative Werte auf die unterste Stufe ab - eingespeiste Stunden sind damit von den schwächsten Bezugsstunden nicht zu unterscheiden.
  - Web: `apps/web/src/components/reports/YearMap.tsx:17, 37, 63-70 mit RAMP_NET und robustMax in apps/web/src/components/reports/charts.ts:413-424`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:188-200 (farbe(_:) normiert auf das Maximum, min(1, max(0, wert/hoechster))) und 127-136 (skala: nur "wenig"/"viel")`
- **klein** · zustand — Die Webseite sagt es, wenn ein Jahr keine Stundenwerte hat ("Für 2023 liegen keine Stundenwerte vor."), und nennt unter der Karte den Werteumfang von min bis max. Die iOS-Seite zeichnet in diesem Fall ein leeres Raster ohne Satz; der Leerzustand greift nur, solange noch nichts geholt ist.
  - Web: `apps/web/src/components/reports/YearMap.tsx:85-89, 127, 137`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/JahreskarteSeite.swift:26-41 (if let karte … else Leer(satz: "Wird geholt …") - kein Zweig für hoursWithData == 0)`

### `/strom/pv`  ·  3 Punkte, davon 1 spürbar

- **spürbar** · abschnitt — Der ganze Prognoseteil fehlt: die Webseite zeigt "Prognose heute" und "Prognose morgen" in kWh und daneben die Kurve "Heute und morgen" - erwartete PV-Leistung aus dem Fahrplan gegen die gemessene Leistung des Tages. Die iOS-PV-Seite fragt weder den Fahrplan (plan) noch den Verlauf (history) ab und hat keine der drei Darstellungen.
  - Web: `apps/web/src/components/reports/PvReport.tsx:46-61, 96-97, 106-109 mit pvForecastChart in apps/web/src/components/reports/charts.ts:178`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:103-148 (PvSeite: nur energieUebersicht, danach Kacheln, ein Balkenbild und Methode - kein api.plan(), kein api.verlauf())`
- **mittel** · abschnitt — Die Webseite hat den Abschnitt "PV im Überblick" (Erzeugt, Eigenverbrauch, Einspeiseerlös, Ersparnis = PV direkt plus Batterieentladung) für Tag, Woche, Monat und Jahr nebeneinander. Auf der iOS-Seite gibt es keinen Mehrspannen-Vergleich und auch die zusammengesetzte Ersparnis nicht.
  - Web: `apps/web/src/components/reports/PvReport.tsx:111-120`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:103-148 (PvSeite hat nur Kachelfeld, ein Balkenbild, Methode)`
- **klein** · kennzahl — Die Webseite nennt an der Kachel "Eingespeist" den Erlös in Euro und den Vergütungssatz ("Erlös 12,40 € bei 8,2 ct"). Die iOS-Seite zeigt die eingespeisten kWh ohne Erlös und ohne Satz.
  - Web: `apps/web/src/components/reports/PvReport.tsx:90`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:129-147 (kennzahlen(_:) der PvSeite: exportKwh ohne exportRevenueEur/feedInCtKwh)`

### `/strom/speicher`  ·  7 Punkte, davon 2 spürbar

- **spürbar** · kennzahl — Die Webseite zeigt "Verlust im Gerät": die Energie, die der Wandler als Ladung sah und die die Zellen nie erreichte (battery_device_kwh), dazu was sie gekostet hat und was dadurch entgangen ist. Auf der iOS-Seite kommt das nirgends vor.
  - Web: `apps/web/src/components/reports/BatteryReport.tsx:138-144`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:208-233 (kennzahlen(_:) der SpeicherSeite; batteryDeviceKwh/batteryDeviceCostEur/batteryDeviceOpportunityEur stehen in keiner Seite der App)`
- **spürbar** · diagramm — Die Webseite zeigt "Ladezustand über den Tag": zwei übereinanderliegende Flächen aus Minutenwerten - oben der Ladestand in Prozent, unten die Speicherleistung (+ Entladen, − Laden). Die iOS-Seite holt für den Speicher keine Minutenreihe und hat diesen Verlauf nicht.
  - Web: `apps/web/src/components/reports/BatteryReport.tsx:58-81, 157-161 mit batteryDayChart in apps/web/src/components/reports/charts.ts:236-275`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:155-206 (SpeicherSeite holt nur energieUebersicht und speicherPruefung; kein api.verlauf/verlaufTag, kein Verlaufsbild)`
- **mittel** · kennzahl — Die Webseite zeigt "Vollzyklen" (Entladung geteilt durch die Kapazität, dazu die Kapazität selbst im Seitenkopf). Die iOS-Seite nennt weder Vollzyklen noch die Kapazität.
  - Web: `apps/web/src/components/reports/BatteryReport.tsx:94, 103, 115`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:208-233 (keine Zyklenzahl; meta.batteryCapacityKwh wird von keiner Seite der App gelesen)`
- **mittel** · bedienung — Die Webseite lässt auf dieser Seite die Untergrenze des Ladestands stellen (aus / 6 / 10 / 15 / 20 %, reserve_soc) und zeigt dazu Betriebsart, Ladestand und die Rückmeldung des Geräts. Die iOS-Speicherseite hat keine Steuerung, und auch das Batterieblatt der App sendet nur die Betriebsart ohne reserveSoc - die Untergrenze lässt sich in der App nirgends stellen.
  - Web: `apps/web/src/components/reports/BatteryControl.tsx:103-117 (Untergrenze), eingehängt in BatteryReport.tsx:146`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:155-206 (SpeicherSeite ohne jede Bedienung); apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:532-538 (stelle(_:) sendet BatteryModeIn(mode:durationMin:), reserveSoc bleibt nil)`
- **mittel** · zustand — Die Webseite warnt an den Herkunftskacheln, wenn ein Teil des Zeitraums nur als Stundenmittel vorliegt: "Aufteilung für 23 % des Zeitraums geschätzt" (coarse_minutes). Die iOS-Seite zeigt diesen Güte-Hinweis nicht.
  - Web: `apps/web/src/components/reports/BatteryReport.tsx:92-93, verwendet in 106, 112, 124`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:200-204 (Methode der SpeicherSeite: nur estimatedNoteDe und ein Satz zur Herkunft; coarseMinutes kommt in keiner Seite vor)`
- **klein** · kennzahl — Die Webseite zeigt den PV-Anteil der Ladung als Prozentwert und, wenn der Ladestandsvergleich nicht möglich ist, den Wirkungsgrad (Entladen geteilt durch Geladen). Die iOS-Seite nennt nur die absoluten kWh aus Sonne und Netz, keinen der beiden Anteile.
  - Web: `apps/web/src/components/reports/BatteryReport.tsx:95-96, 124, 134`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:208-233`
- **klein** · abschnitt — Die Webseite hat den Abschnitt "Speicher im Überblick" (Ersparnis netto, Entladen, Vollzyklen, PV-Anteil) für Tag, Woche, Monat und Jahr nebeneinander; die iOS-Seite zeigt immer nur die gewählte Spanne.
  - Web: `apps/web/src/components/reports/BatteryReport.tsx:162-171`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:155-206`

### `/strom/wallbox`  ·  5 Punkte, davon 2 spürbar

- **spürbar** · diagramm — Die Webseite zeigt die geladene Energie als gestapelte Balken je Zeitschritt nach Herkunft (aus PV, aus Batterie, aus Netz). Die iOS-Seite hat überhaupt kein Diagramm - nur Kacheln und die Tabelle der Ladevorgänge.
  - Web: `apps/web/src/components/reports/EvReport.tsx:14-18, 46-51`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:237-272 (WallboxSeite: Kachelfeld, Karte mit Tabelle, Methode - kein Balkenbild)`
- **spürbar** · kennzahl — Die Webseite zeigt den Sonnenanteil des Zeitraums als Prozentwert und rechnet dafür die Ladung aus der Batterie mit (ev_battery_kwh, Hinweis "PV 7,2 · Batt. 3,1 kWh"). Die iOS-Seite kennt nur Sonne und Netz in kWh; der Batterieanteil und der Prozentwert fehlen ganz.
  - Web: `apps/web/src/components/reports/EvReport.tsx:28, 40`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:274-289 (kennzahlen(_:) der WallboxSeite: evKwh, Anzahl, evPvKwh, evGridKwh, evCostEur, evOpportunityEur; evBatteryKwh wird in keiner Seite gelesen)`
- **mittel** · kennzahl — Die Webseite zeigt zwei Preiskennzahlen: "Effektiv je kWh" in ct (Bezahltes plus Entgangenes je geladener kWh) und den mittleren bezahlten Preis des Netzanteils ("Ø 31,2 ct/kWh bezahlt"). Beides fehlt auf der iOS-Seite.
  - Web: `apps/web/src/components/reports/EvReport.tsx:29-30, 41, 44`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:274-289`
- **klein** · kennzahl — In der Tabelle der Ladevorgänge zeigt die Webseite zusätzlich die Dauer je Vorgang ("1 h 25 min") und stellt die jüngste Ladung nach oben; die iOS-Tabelle nennt nur Beginn und Ende und übernimmt die Reihenfolge des Dienstes.
  - Web: `apps/web/src/components/reports/EvReport.tsx:32, 63, 71, 75`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:243-269 (Zeilenname "hh:mm – hh:mm", Spalten kWh, Sonnenanteil, Netz, Kosten, mittlere Leistung; keine Dauer, keine Sortierung)`
- **klein** · abschnitt — Die Webseite hat den Abschnitt "Wallbox im Überblick" (Geladen, Sonnenanteil, Bezahlt, Ladevorgänge) für Tag, Woche, Monat und Jahr nebeneinander; die iOS-Seite zeigt immer nur die gewählte Spanne.
  - Web: `apps/web/src/components/reports/EvReport.tsx:91-100`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:237-272`

### `/system/daten`  ·  4 Punkte, davon 2 spürbar

- **spürbar** · diagramm — Die Webseite legt die Messreihen des Tages uebereinander auf eine kW-Achse (Erzeugung, Haus, Netz, Speicher, dazu gestrichelt Ladestand und amtlicher Zaehler) mit waehlbarem Zeitfenster, samt Leerzustand "Fuer diesen Tag liegen keine Minutenwerte vor"; die iOS-Seite zeigt keine Messreihen und fragt den Tagesverlauf gar nicht ab.
  - Web: `apps/web/src/components/reports/DataCheck.tsx:38 (api.historyDay) und :71-86 (Karte "Leistungen ueber den Tag" mit powerOverlay und Leerzustand)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:453-591 - DatenSeite holt in lade() nur abdeckung, datenbestand und diagnose; verlaufTag(_:) aus DuckCurveKit/Sources/DuckCurveKit/Netz/Api.swift:155 wird auf dieser Seite nicht gerufen`
- **spürbar** · abschnitt — Die Webseite zeigt die Karte "Quellen - liefert gerade, was liefern soll?": je Quelle ein Punkt online/offline mit dem fertigen Satz des Dienstes (Zaehler, Abfragen, Alter des letzten Messwerts) und darueber die Zeile, ob die Anforderung an die Waermepumpe wirklich geschaltet wird. Die iOS-Seite hat dazu nichts.
  - Web: `apps/web/src/components/reports/DataCheck.tsx:91-96 (Karte "Quellen") mit apps/web/src/components/reports/Sources.tsx:47-81 (state.system.sources, online, detail_de, hp_actuation)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:453-591 - kein Zugriff auf haus.zustand?.system.sources; SourceStatusOut (Schema.swift:8199) wird in der ganzen App nirgends angezeigt`
- **mittel** · diagramm — Die Webseite zeigt die Abdeckung als Flaeche aus Tagen und Stunden (Minuten je Stunde, 0 bis 60, 28 Tage) und unterscheidet dabei leere Zelle (keine Minutenzeile, Ausfall des Dienstes) von roter Zelle (Reihe fehlt); die App fasst dieselben Daten nur je Reihe zu einer Zeile zusammen, das Muster je Stunde fehlt.
  - Web: `apps/web/src/components/reports/CoverageMap.tsx:104-131 (yearMap ueber series.hours, "Kommen die Daten an? 28 Tage")`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:478-520 - Tabelle mit vollstaendig, Minuten, lueckige Stunden, laengste Luecke, zuletzt; die Stundenwerte je Reihe (CoverageSeriesOut.hours) werden nicht dargestellt`
- **mittel** · bedienung — Die Webseite bietet die Minutenwerte des angezeigten Tages als CSV zum Herunterladen an; in der App gibt es keinen Export.
  - Web: `apps/web/src/components/reports/DataCheck.tsx:52-56 und :100-110 (Verweis "Minutenwerte dieses Tages als CSV" auf /api/dch/export/minutes)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:453-591 - kein Knopf und kein ShareLink; in apps/ios/DuckCurveHome gibt es ueberhaupt keinen Aufruf eines Export-Endpunkts`

### `/system/haustuer`  ·  1 Punkte

- **mittel** · kennzahl — Die Webseite ordnet jeden Eintrag einem Tag zu (Heute, Gestern, sonst Wochentag und Datum als Ueberschrift der Gruppe); die App zeigt je Eintrag nur die Uhrzeit, so dass bei 7, 30 oder 90 Tagen nicht zu erkennen ist, an welchem Tag jemand vor der Tuer stand.
  - Web: `apps/web/src/components/settings/DoorLog.tsx:24-32 (dayLabel) und :121-134 (Gruppen je Tag mit Ueberschrift)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:636-658 - eintrag(_:) setzt nur Formate.hhmm(iso: e.at); die Liste ab Zeile 618 ist flach, ohne Tagesgruppe und ohne Datum`

### `/system/mitteilungen`  ·  3 Punkte

- **mittel** · zustand — Nach einer Probe und nach dem Versand des Briefings zeigt die Webseite die Einzelheiten je Gerat (details_de), also woran eine Zustellung scheiterte; die App zeigt nur den einen Satz message_de.
  - Web: `apps/web/src/components/settings/Mitteilungen.tsx:175-176 und :246-250 (details_de als Liste) sowie apps/web/src/components/settings/Morgenbrief.tsx:55-56 und :106-110`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:211-241 - probe() und sendeBrief() uebernehmen nur a.messageDe; detailsDe (PushResultOut, Schema.swift) wird in der ganzen App nicht gelesen`
- **mittel** · zustand — Ist kein Gerat angemeldet, warnt die Webseite ausdruecklich ("Kein Gerat angemeldet" und: dann gehen weder Stoerungen noch das Morning Briefing an jemanden, beim Briefing zusaetzlich aus stand.geraete); die App laesst die Geratekarte in diesem Fall einfach weg und sagt nichts.
  - Web: `apps/web/src/components/settings/Mitteilungen.tsx:252-267 (Leerzustand mit Warnsatz) und apps/web/src/components/settings/Morgenbrief.tsx:99-103 (Warnung bei geraete == 0)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:29-38 - die Karte steht unter `if let g = geraete, !g.devices.isEmpty`, es gibt keinen else-Zweig; b.geraete aus MorgenbriefOut wird in morgenbrief(_:) (Zeile 139-180) nicht ausgewertet`
- **klein** · bedienung — Die Webseite laesst auch dann eine Probe an die angemeldeten Gerate schicken, wenn dieses Gerat selbst nicht angemeldet ist; in der App gibt es den Probeknopf nur im Zustand "angemeldet".
  - Web: `apps/web/src/components/settings/Mitteilungen.tsx:238-242 ("Probe an die angemeldeten Gerate", wenn lage != "an" und Gerate vorhanden)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:58-72 - "Probe senden" steht allein im Fall .angemeldet des switch ueber mitteilungen.stand; in den Faellen .ungefragt, .erlaubt, .abgelehnt und .fehler gibt es keinen Probeknopf`

### `/system/zugang`  ·  1 Punkte, davon 1 spürbar

- **spürbar** · bedienung — Die Webseite bietet die jaehrliche Sicherung an: Minutenwerte und Stundenbilanz des laufenden und des vorigen Jahres zum Herunterladen (die Stundenbilanz traegt die Grundlagen der PV-Abrechnung); in der App gibt es keine Moeglichkeit, die Daten herauszuholen.
  - Web: `apps/web/src/app/system/zugang/page.tsx:134-149 (je Jahr "Minutenwerte" und "Stundenbilanz" auf /api/dch/export/minutes bzw. /export/hours)`
  - iOS: `apps/ios/DuckCurveHome/App/Einrichten.swift:235-336 - ZugangSeite hat die Karten Dieses Gerat, Verbindung, Angemeldete Gerate und Aendern; kein Export, kein ShareLink, und in apps/ios/DuckCurveHome wird kein Export-Endpunkt aufgerufen`

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

