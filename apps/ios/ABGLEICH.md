# Was die App noch nicht zeigt

**Die Adressen sind vollständig, der Inhalt ist es nicht.** Alle 28 Inhaltsseiten des
Dashboards haben in der App eine Entsprechung unter derselben Adresse – das ist nachgemessen.
Ob dort auch *dasselbe steht*, sagt eine Adressliste nicht, und die Antwort lautet: auf
mehreren Seiten nein.

## Woher diese Liste kommt, und was sie nicht ist

Sie entstand maschinell: je Bereich ein Leser, der die Quelle der Webseite
(`apps/web/src/app/<adresse>/page.tsx` samt ihren Komponenten) gegen die SwiftUI-Ansicht
hielt, die `apps/ios/DuckCurveHome/App/Seitenwahl.swift` für diese Adresse zurückgibt.

**Jeder Eintrag ist die Behauptung eines einzelnen Lesers und von niemandem geprüft.** Der
Lauf hatte eine zweite Stufe – je Lücke zwei Skeptiker, die sie widerlegen sollten – und diese
Stufe ist vollständig ausgefallen: alle 156 Prüfagenten scheiterten an einer
Nutzungsgrenze. Was hier steht, ist also **Verdacht, nicht Befund.** Vor dem Umsetzen gehört
jeder Punkt am Code nachgesehen; erfahrungsgemäß ist ein Teil davon keine Lücke, sondern eine
andere Gliederung oder ein anderer Name für dieselbe Sache.

## Abdeckung

| | |
|---|---|
| verglichen | 15 von 28 Seiten |
| nicht verglichen | 12 Seiten – der ganze Wärmebereich |
| Verdachtsfälle | 78 |
| davon spürbar / mittel / klein | 23 / 31 / 24 |
| davon geprüft | **0** |

Nicht verglichen (drei Lesergruppen fielen vor dem Lauf aus):

- `/waerme`
- `/waerme/anlage`
- `/waerme/annahmen`
- `/waerme/raeume`
- `/waerme/waermepumpe`
- `/waerme/waermepumpe/betrieb`
- `/waerme/waermepumpe/kennlinie`
- `/waerme/waermepumpe/regler`
- `/waerme/fahrplan`
- `/waerme/nachbetrachtung`
- `/waerme/wiedergabe`
- `/waerme/wirkung`

## Die Verdachtsfälle, nach Seite

### `/`

- **spürbar** · kennzahl — Die Webseite zeigt unter der Kurve die Autarkie des Tages ("ohne Netz", in Prozent) als eine der vier Kennzahlen; die iOS-Seite hat an dieser Stelle "im Haus" in kWh und nennt die Autarkie nirgends.
  - Web: `apps/web/src/components/home/tage.ts:125 (`{ wert: t?.autarky != null ? String(Math.round(t.autarky * 100)) : "-", einheit: "%", wort: "ohne Netz" }`), eingesetzt in apps/web/src/components/home/Home.tsx:179/236-243`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift - die vier Kacheln entstehen in `kennzahlen` (Zeilen 139-179) aus `zustand.todayKwh` bzw. `gesternKwh` (181-189); kein `autarky` in der ganzen Datei, und auch sonst nur auf der Stromseite (apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:34).`
- **spürbar** · kennzahl — Die Webseite zeigt als dritte Kennzahl, was der Tag an Netzstrom gekostet hat ("bezahlt bis jetzt" heute, "bezahlt" gestern, in Euro); auf der iOS-Seite steht dort "für die Wärme" in kWh, Geld kommt auf der Jetzt-Seite nicht vor.
  - Web: `apps/web/src/components/home/tage.ts:126 (`{ wert: de(t?.import_cost_eur ?? null, 2), einheit: "€", wort: tag === "heute" ? "bezahlt bis jetzt" : "bezahlt" }`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:158-179 - die vier Kacheln für gestern/heute sind Sonne, Haus, Wärme und Preis/Netz; `importCostEur` oder ein Eurobetrag steht in der ganzen Datei nicht.`
- **mittel** · endpunkt — Die Webseite holt für den laufenden Tag die Tagesbilanz (`/energy/summary?span=day`) und hält sie alle fünf Minuten frisch - daraus kommen Autarkie, bezahlte Kosten und der Mittelpreis; die iOS-Seite fragt diesen Endpunkt nur für gestern ab und rechnet heute allein aus den Live-Summen.
  - Web: `apps/web/src/components/home/Home.tsx:59-70 (`useTagesbilanz` mit `api.energySummary("day", day)`) und :128 (`const bilanzHeute = useTagesbilanz(heute)`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:232-257 - `ladeFuerTag()` ruft `haus.api.energieUebersicht("day", anker:)` nur im Zweig `.gestern` (Zeile 246); für `.heute` wird `bilanz = nil` gesetzt (238) und die Kacheln nehmen `zustand.todayKwh` (159).`
- **mittel** · abschnitt — Am Telefon zeigt die Webseite unter dem Energiefluss den Abschnitt "Die nächsten 24 Stunden": aktueller Preis mit Einordnung ("Strom ist gerade günstig/teuer"), die Spanne von tiefstem zu höchstem Preis mit der Stelle, an der man gerade steht, drei Bänder (Preis, erwartete Sonne, geplante Wärmepumpe/Ofen) an einer Zeitachse ab jetzt, dazu Sätze zum günstigsten Fenster mit Mittelpreis, zur meisten Sonne und der Hinweis auf Waschmaschine/Spülmaschine/Trockner; die iOS-Seite hat an dieser Stelle nur die drei Planzeilen.
  - Web: `apps/web/src/components/home/Rail.tsx:82 (`<Ausblick plan={plan} nowMs={nowMs} warnung={plan?.planner_warn_de} />` im kompakten Zweig) mit apps/web/src/components/home/Ausblick.tsx:86-220`
  - iOS: `apps/ios/DuckCurveHome/Bausteine/Leiste.swift:16-49 - die Leiste hat nur die Pufferkarte und die Karte "Als Nächstes" mit `Fahrplan.zeilen`; `kompakt` legt bloß das Pufferglas quer (Zeile 23). Weder Preis-Einordnung noch Bänder noch die Sätze existieren in der App (keine Fundstelle für "günstig"/"Waschmaschine" in apps/ios/DuckCurveHome).`
- **mittel** · kennzahl — Für gestern zeigt die Webseite als vierte Zahl den mittleren Bezugspreis des Tages ("Strom im Mittel", aus `avg_import_price_ct`); die iOS-Seite zeigt dort stattdessen die Netzbezugsmenge in kWh, einen Mittelpreis gibt es nicht.
  - Web: `apps/web/src/components/home/tage.ts:119-122 (`tag === "heute" ? ... : { wert: de(t?.avg_import_price_ct ?? null, 1), einheit: "ct", wort: "Strom im Mittel" }`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:170-176 - für `.gestern` steht in der vierten Kachel "aus dem Netz" mit `quelle["grid_in"]`; `gesternKwh` (181-189) liest aus der Tagesbilanz nur pv/house/heat_pump/importKwh, nicht `avgImportPriceCt`.`
- **mittel** · kennzahl — Für morgen zeigt die Webseite den mittleren Börsenpreis des Tages ("Strom im Mittel"); die iOS-Seite zeigt nur tiefsten und höchsten Preis, einen Mittelwert nicht.
  - Web: `apps/web/src/components/home/tage.ts:97-98 und :109 (`mittel` aus allen bekannten Preisen des Morgen-Fensters, Kachel "Strom im Mittel")`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:141-157 (Zweig `.morgen`: Sonne, Strom für die Wärme, "tiefster Preis", "höchster Preis") mit `preisSpanne` (191-197), das nur `min()` und `max()` rechnet.`
- **klein** · kennzahl — Für morgen nennt die Webseite bei der günstigsten Stunde auch, wann sie beginnt ("günstigste Stunde ab 13:00"), und färbt sie bei negativem Preis gelb; die iOS-Seite zeigt nur den tiefsten Preis als Zahl, ohne Uhrzeit.
  - Web: `apps/web/src/components/home/tage.ts:99-101 und :110-115 (`guenstigste` als Punkt mit `ts`, Wort `günstigste Stunde ab ${uhr(guenstigste.ts)}`, `gelb: guenstigste.ct < 0`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:155 (`Kacheldaten("tiefster Preis", preisSpanne.tief, einheit: "ct/kWh")`); `preisSpanne` (191-197) verwirft die Zeitstempel, es wird nur `compactMap(\.priceCtKwh)` gerechnet.`
- **klein** · zustand — Solange die Börse die Preise für morgen noch nicht veröffentlicht hat, sagt die Webseite das im Wort der Kachel ("Preise kommen gegen 13 Uhr"); die iOS-Seite zeigt dann nur einen Strich ohne Erklärung.
  - Web: `apps/web/src/components/home/tage.ts:109 (`wort: ct.length ? "Strom im Mittel" : "Preise kommen gegen 13 Uhr"`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:191-197 - `preisSpanne` gibt bei leeren Preisen `(Formate.leer, Formate.leer)` zurück, die Kachelwörter bleiben "tiefster Preis"/"höchster Preis" (155-156); kein Hinweistext in der Datei.`
- **klein** · kennzahl — Für morgen zeigt die Webseite die erwartete Wärmemenge (thermisch, Heizung plus Warmwasser) als Zahl und den Strom dafür als Zusatz im Wort; die iOS-Seite zeigt nur den Strom für die Wärme, die erwartete Wärme selbst fehlt.
  - Web: `apps/web/src/components/home/tage.ts:76-86 (`waermeSumme` mit `thermisch` und `elektrisch`) und :104-108 (Kachel `wert: thermisch`, `wort: "Wärme erwartet · X kWh Strom"`)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Jetzt/JetztSeite.swift:150-154 - einzige Wärmekachel ist "Strom für die Wärme" mit `waermeKwh24h`, das in `ladeFuerTag()` (252-255) allein aus `forecastElectricKwh24h` kommt; `heating_kw`/`dhw_kw` werden nicht summiert.`
- **klein** · zustand — Die Webseite setzt die Warnung des Planers (`planner_warn_de`) unter die Planzeilen, also dorthin, wo der Plan gezeigt wird; die iOS-Karte "Als Nächstes" zeigt sie nicht.
  - Web: `apps/web/src/components/home/Rail.tsx:99 und :115 (`{warnung ? <span ...>{warnung}</span> : null}` in der Kachel "Nächste 24 h")`
  - iOS: `apps/ios/DuckCurveHome/Bausteine/Leiste.swift:27-47 - die Karte "Als Nächstes" rendert nur `Planzeile.wort`/`.wann`; `plannerWarnDe` kommt in der Datei nicht vor (in der App nur auf apps/ios/DuckCurveHome/Seiten/Technik/FahrplanSeiten.swift:18).`

### `/geld`

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

### `/haus`

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

### `/strom`

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

### `/system`

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

### `/geld/pv-abrechnung`

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

### `/geld/rechnungen`

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

### `/strom/jahr`

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

### `/strom/pv`

- **spürbar** · abschnitt — Der ganze Prognoseteil fehlt: die Webseite zeigt "Prognose heute" und "Prognose morgen" in kWh und daneben die Kurve "Heute und morgen" - erwartete PV-Leistung aus dem Fahrplan gegen die gemessene Leistung des Tages. Die iOS-PV-Seite fragt weder den Fahrplan (plan) noch den Verlauf (history) ab und hat keine der drei Darstellungen.
  - Web: `apps/web/src/components/reports/PvReport.tsx:46-61, 96-97, 106-109 mit pvForecastChart in apps/web/src/components/reports/charts.ts:178`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:103-148 (PvSeite: nur energieUebersicht, danach Kacheln, ein Balkenbild und Methode - kein api.plan(), kein api.verlauf())`
- **mittel** · abschnitt — Die Webseite hat den Abschnitt "PV im Überblick" (Erzeugt, Eigenverbrauch, Einspeiseerlös, Ersparnis = PV direkt plus Batterieentladung) für Tag, Woche, Monat und Jahr nebeneinander. Auf der iOS-Seite gibt es keinen Mehrspannen-Vergleich und auch die zusammengesetzte Ersparnis nicht.
  - Web: `apps/web/src/components/reports/PvReport.tsx:111-120`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:103-148 (PvSeite hat nur Kachelfeld, ein Balkenbild, Methode)`
- **klein** · kennzahl — Die Webseite nennt an der Kachel "Eingespeist" den Erlös in Euro und den Vergütungssatz ("Erlös 12,40 € bei 8,2 ct"). Die iOS-Seite zeigt die eingespeisten kWh ohne Erlös und ohne Satz.
  - Web: `apps/web/src/components/reports/PvReport.tsx:90`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Energie/StromSeite.swift:129-147 (kennzahlen(_:) der PvSeite: exportKwh ohne exportRevenueEur/feedInCtKwh)`

### `/strom/speicher`

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

### `/strom/wallbox`

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

### `/system/daten`

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

### `/system/haustuer`

- **mittel** · kennzahl — Die Webseite ordnet jeden Eintrag einem Tag zu (Heute, Gestern, sonst Wochentag und Datum als Ueberschrift der Gruppe); die App zeigt je Eintrag nur die Uhrzeit, so dass bei 7, 30 oder 90 Tagen nicht zu erkennen ist, an welchem Tag jemand vor der Tuer stand.
  - Web: `apps/web/src/components/settings/DoorLog.tsx:24-32 (dayLabel) und :121-134 (Gruppen je Tag mit Ueberschrift)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/SystemSeiten.swift:636-658 - eintrag(_:) setzt nur Formate.hhmm(iso: e.at); die Liste ab Zeile 618 ist flach, ohne Tagesgruppe und ohne Datum`

### `/system/mitteilungen`

- **mittel** · zustand — Nach einer Probe und nach dem Versand des Briefings zeigt die Webseite die Einzelheiten je Gerat (details_de), also woran eine Zustellung scheiterte; die App zeigt nur den einen Satz message_de.
  - Web: `apps/web/src/components/settings/Mitteilungen.tsx:175-176 und :246-250 (details_de als Liste) sowie apps/web/src/components/settings/Morgenbrief.tsx:55-56 und :106-110`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:211-241 - probe() und sendeBrief() uebernehmen nur a.messageDe; detailsDe (PushResultOut, Schema.swift) wird in der ganzen App nicht gelesen`
- **mittel** · zustand — Ist kein Gerat angemeldet, warnt die Webseite ausdruecklich ("Kein Gerat angemeldet" und: dann gehen weder Stoerungen noch das Morning Briefing an jemanden, beim Briefing zusaetzlich aus stand.geraete); die App laesst die Geratekarte in diesem Fall einfach weg und sagt nichts.
  - Web: `apps/web/src/components/settings/Mitteilungen.tsx:252-267 (Leerzustand mit Warnsatz) und apps/web/src/components/settings/Morgenbrief.tsx:99-103 (Warnung bei geraete == 0)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:29-38 - die Karte steht unter `if let g = geraete, !g.devices.isEmpty`, es gibt keinen else-Zweig; b.geraete aus MorgenbriefOut wird in morgenbrief(_:) (Zeile 139-180) nicht ausgewertet`
- **klein** · bedienung — Die Webseite laesst auch dann eine Probe an die angemeldeten Gerate schicken, wenn dieses Gerat selbst nicht angemeldet ist; in der App gibt es den Probeknopf nur im Zustand "angemeldet".
  - Web: `apps/web/src/components/settings/Mitteilungen.tsx:238-242 ("Probe an die angemeldeten Gerate", wenn lage != "an" und Gerate vorhanden)`
  - iOS: `apps/ios/DuckCurveHome/Seiten/Technik/MitteilungenSeite.swift:58-72 - "Probe senden" steht allein im Fall .angemeldet des switch ueber mitteilungen.stand; in den Faellen .ungefragt, .erlaubt, .abgelehnt und .fehler gibt es keinen Probeknopf`

### `/system/zugang`

- **spürbar** · bedienung — Die Webseite bietet die jaehrliche Sicherung an: Minutenwerte und Stundenbilanz des laufenden und des vorigen Jahres zum Herunterladen (die Stundenbilanz traegt die Grundlagen der PV-Abrechnung); in der App gibt es keine Moeglichkeit, die Daten herauszuholen.
  - Web: `apps/web/src/app/system/zugang/page.tsx:134-149 (je Jahr "Minutenwerte" und "Stundenbilanz" auf /api/dch/export/minutes bzw. /export/hours)`
  - iOS: `apps/ios/DuckCurveHome/App/Einrichten.swift:235-336 - ZugangSeite hat die Karten Dieses Gerat, Verbindung, Angemeldete Gerate und Aendern; kein Export, kein ShareLink, und in apps/ios/DuckCurveHome wird kein Export-Endpunkt aufgerufen`

