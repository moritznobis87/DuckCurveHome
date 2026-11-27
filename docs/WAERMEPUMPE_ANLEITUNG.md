# Was die Anleitung der Wärmepumpe für den Bus hergibt

Stand 27.11.2026. Gelesen ist die „Bedienungsanleitung für den Fachhandwerker“ der ELCO
AEROTOP SPLIT M-CRX und M-CR (Dokument 420010756202, Ausgabe 10/2017, deutscher Teil, Seiten 2
bis 50), die der Hausherr am 27.11.2026 hochgeladen hat. Die Datei selbst liegt nicht im
Repository, weil sie dem Hersteller gehört; die Seitenzahlen hier sind die gedruckten.

Verglichen ist sie mit `addons/duckcurve_ebusd/*.csv`,
`apps/api/src/dch_api/application/regler.py` und `waermepumpe.py` sowie `docs/SENSORIK.md`.
**Geändert ist am Code nichts.** Jeder Fund nennt, was er im Haus noch braucht, bevor er gilt.

## Vorweg: die Anleitung gehört zu einem Schwestermodell

`docs/SENSORIK.md` führt die Anlage als AEROTOP SPLIT WH 09-11 an einem Kombipuffer von 1000 l.
Die Anleitung beschreibt die M-CRX und M-CR: 4 bis 7 kW, Inneneinheit mit eingebautem
Warmwasserspeicher. Regler (Energy Manager), Bediengerät (Remocon Plus), Bus (BridgeNet auf
den Klemmen B und T) und das Menü 17 sind dieselbe Familie; dafür spricht, dass die Zahlen aus
dem Haus zu den Listen der Anleitung passen (siehe unten).

* **Übertragbar mit guter Aussicht:** Menünummern, Wertebereiche, Reihenfolge der Auswahllisten,
  Statuslisten, Fehlerlisten, Klemmenbelegung des Reglers.
* **Nicht übertragbar ohne das Typenschild:** alles, was an der Größe der Maschine hängt, also
  Durchflussschwellen, Nenndurchfluss, Stufen des Heizstabs und Kältemittelmenge.
* **Der Typ:** Der Hausherr am 27.11.2026: „Ich habe die 9-kW-Anlage.“ Das passt zur Angabe
  WH 09-11 und nicht zu dieser Anleitung, die bei 7 kW endet. Eine zweite Datei, die er dazu
  hochlud, war dieselbe Anleitung noch einmal (gleicher Titel, Wort für Wort gleicher Text). Die
  Anleitung der 9-kW-Anlage liegt also noch nicht vor.

## 1. Die Statuslisten der Anleitung passen zu den Zahlen aus dem Haus

Die Menütabelle zählt die Zustände in fester Reihenfolge auf (Seiten 42 und 43). Von null an
gezählt ergibt das die Zahlen des Busses.

**Betriebszustand der Maschine** (Parameter 17.11.0, im Bus Kennung `ca46`): aus, Stand-by,
Kühlen, Heizen, Booster Heizen, Booster Kühlen, Rating Heizbetrieb, Rating Kühlbetrieb,
Frostschutz, Enteisen, Hochtemperatur-Schutz, Zeitschutz, Systemfehler, großer Systemfehler,
Pump Down, sanfter Fehlermodus. Das deckt sich Zahl für Zahl mit `ZUSTAND_DE` in
`waermepumpe.py`, das bisher nur auf der fremden Bus-Beschreibung stand, einschließlich der 15,
die im Haus der gewöhnliche Stillstand ist. Neu benannt sind 6, 7, 13 und 14.

**Status des Reglers** (Parameter 17.14.0, im Bus Kennung `c94b`):

| Zahl | Anleitung | Stand im Haus |
|---|---|---|
| 0 | Stand-by | bestätigt |
| 1 | Frostschutz-Zyklus | nicht gesehen |
| 2 | Heizen-Zyklus | bestätigt |
| 3 | Heiztemperatur erreicht | nicht gesehen; die fremde Liste nennt die 3 „DHW Cycle“ |
| 4 | Warmwasser-Zyklus | nicht gesehen |
| 5 | Legionellenschutz | nicht gesehen |
| 9 | keine Wärmeerzeugung | nicht gesehen |
| 16 | Einbindung Photovoltaik | gesehen in der Nacht vom 13. auf den 14.11. |
| 19 | Enteisen | nicht gesehen |
| 20 | Pufferheizung und Warmwasser | gesehen am Vormittag des 14.11. mit knapp 6 kW neben dem Verdichter |
| 22 | steht nicht in der Liste | gesehen, stehend, Sekunden vor dem Start |

Dazwischen stehen Entlüftung (6), Schornsteinfeger (7), Bodentrocknung (8), manuell (10),
Fehlermeldung (11), Initialisierung (12), aus (13), Kühlen (14), Warmwasser-Frostschutz (15),
Entfeuchtung (17) und Pump Down (18).

* Die 20 hieß in der fremden Liste „Puffer kühlen“ und stand so an einer heizenden Maschine.
  „Pufferheizung und Warmwasser“ passt zu dem Lauf, in dem der Hausherr eine
  Warmwasserbereitung vermutete.
* **Ein Widerspruch:** Die Kommentare in `aerotop_split.csv` und `waermepumpe.py` lesen die 3
  als Warmwasser. Nach der Anleitung ist Warmwasser die 4. Entschieden wird das beim ersten
  Warmwasserlauf, den das Haus mitschreibt.
* **Die 16 in der Nacht ist erklärt.** Der Hausherr am 27.11.2026: Der Shelly, über den die
  Wärmepumpe angefordert wird (K1), liegt am Eingang für den PV-Überschuss. Der Planer schließt
  ihn auch in günstigen Nachtstunden; der Regler meldet dann „Einbindung Photovoltaik“, gleich
  woher der Strom kommt. Bestätigt ist die 16 damit, sobald ein Verlauf sie neben
  `hp_release_contact` zeigt.
* Die Liste endet bei 20. Die 22 aus dem Haus kennt sie nicht; der Regler im Haus ist also
  jünger als die Anleitung, und die Liste ist nicht vollständig.

## 2. Wertebereiche: wo die Grenzen in `regler.py` von der Anleitung abweichen

Menütabelle Seiten 36 bis 41. Die Grenzen im Code stammen aus der fremden Bus-Beschreibung.

| Einstellung | im Code | Anleitung | Folge |
|---|---|---|---|
| Spartemperatur Warmwasser (17.5.1) | 20 bis 55 °C | 35 °C bis zur Komforttemperatur | Unter 35 °C nimmt der Regler den Wert vermutlich nicht an. |
| Vorlauf höchstens (4.2.5) | 25 bis 60 °C | 20 bis 45 °C im niedrigen, 20 bis 70 °C im hohen Temperaturbereich | Die Grenze hängt vom Temperaturbereich (4.2.0) ab; im niedrigen Bereich ist über 45 °C nichts zu stellen. |
| Steilheit (4.2.2) | 0,2 bis 3,5 | 0,2 bis 1,0 niedrig, 0,4 bis 3,5 hoch | wie oben |
| Verschiebung (4.2.3) | −7 bis +7 K | ±7 K niedrig, ±14 K hoch | passt für den niedrigen Bereich |
| Komforttemperatur Warmwasser (17.5.0) | 35 bis 60 °C | 35 bis 65 °C | Der Code ist enger; das ist gewollt vertretbar. |
| Betriebsart Warmwasser (17.5.2) | 0 bis 2 | sechs Werte: deaktiviert, zeitbasiert, ständig, Heizen mit Signal, Heizen 40 °C mit Signal, Green | Werkseinstellung ist Green, also die 5, für die der Code kein Wort hat. |
| Komfortstufe (17.2.2) | Lesart 0 Eco, 1 Eco plus | Reihenfolge Eco plus, Eco, Normal, Komfort, Komfort plus | Die ersten beiden Wörter stehen im Code vermutlich vertauscht. |
| Korrektur des Vorlaufs (17.2.3) | nur gelesen | 0 bis 10 K, ab Werk 2 K | Gleicht den Verlust zwischen Außen- und Innengerät aus. |
| Zuschlag bei Sonnenstrom (17.0.5) | nur gelesen | 0 bis 20 K, ab Werk 0 K | siehe Abschnitt 4 |
| Sommerbetrieb ab (4.1.1) | nur gelesen | 10 bis 30 °C, ab Werk 20 °C | Wirkt nur, wenn 4.1.0 eingeschaltet ist; ab Werk ist es aus. |

`heat_mode` (0 Green, 1 Standard) und `pump_mode` stimmen mit der Reihenfolge der Anleitung
überein. „Wärmepumpe aus unter“ (`7226`) kommt in dieser Anleitung nicht vor.

## 3. Der Heizstab: Stufen und die Gründe, aus denen er zuschaltet

`docs/SENSORIK.md` hielt fest, dass in keiner Unterlage steht, welche Stufen der Heizstab hat.
Für die M-CRX steht es hier (Parameter 17.8.6, Seite 33): 2 + 2 kW, wahlweise mit einer dritten
Stufe von 2 kW, oder 2 + 4 kW. Die kleinste Stufe sind 2 kW; die gesetzte Schwelle
`kennlinie.ZUSATZ_KW` von 1,5 kW liegt damit richtig darunter. Für die WH 09-11 ist das am
Typenschild zu prüfen (Feld „Nennleistung der Heizwiderstände“).

Wann er zuschaltet, und womit es sich verhindern lässt:

* **Warmwasser dauert zu lange.** Nach der „Max WP Ladezeit“ (17.5.3, ab Werk 120 Minuten)
  schalten die Heizstäbe zu (Seiten 31 und 32).
* **Heizen kommt nicht nach.** Die Komfortstufe (17.2.2) legt die Wartezeit fest, von lang
  (Eco plus) bis kurz (Komfort plus).
* **Legionellenprogramm.** Der Speicher wird alle 30 Tage für eine Stunde auf 60 °C gebracht
  (17.5.4), ab Werk um 01:00 Uhr (17.5.5). Die Startzeit ist einstellbar und gehörte in die
  Mittagsstunden mit Sonnenstrom.
* **Schnellladung** (17.0.4), höchstens 180 Minuten.
* **Frostschutz der Inneneinheit**, wenn der Rücklauf trotz Pumpe unter 7 °C bleibt (Seite 46).
* **Verhindern:** Heizbetrieb Green (17.0.0, im Code `heat_mode`) heizt ohne Heizstab;
  „Elektroeinsatz Einstellung“ (17.2.6) legt die Zahl der aktiven Stufen fest, Stufe 0 heißt
  keine.

Ob er läuft, zeigt der Regler selbst: je Stufe ein Ausgang (17.15.4 bis 17.15.6) und je Stufe
ein Stundenzähler (17.9.2 bis 17.9.4). Der Zähler beantwortet die Frage aus `SENSORIK.md`
(„vermutlich der Heizstab“) ohne Rechnung, sobald seine Kennung gefunden ist.

## 4. Ansteuern ohne Schreiben: die 230-V-Eingänge des Reglers

Jedes Stellen über den Bus schreibt in den Speicher des Reglers; deshalb gilt `STELLEN_JE_TAG`.
Der Regler hat für genau den Zweck des Hauses drei Eingänge für 230 V (Seiten 22, 23, 30, 33),
die nichts schreiben:

| Eingang | Parameter | Wirkung |
|---|---|---|
| HV IN 3 | 17.1.2 „PV-Einbindung aktiv“ | Liegt Spannung an und steht die Anlage in Bereitschaft, steigt der Warmwassersollwert um den Zuschlag aus 17.0.5 (0 bis 20 K). |
| HV IN 1 und HV IN 2 | 17.1.0 und 17.1.1 auf SG-Ready | Beide zusammen bilden vier Zustände, siehe unten. |

| HV IN 1 | HV IN 2 | Wirkung nach SG-Ready |
|---|---|---|
| 0 V | 0 V | gewöhnlicher Betrieb |
| 230 V | 0 V | Anlage höchstens zwei Stunden aus, Frostschutz bleibt |
| 0 V | 230 V | Im Zeitprogramm gilt statt der abgesenkten die Komforttemperatur, Heizstäbe aus |
| 230 V | 230 V | wie zuvor, Heizstäbe freigegeben |

* **K1 ist im Haus der PV-Eingang** (Auskunft des Hausherrn, 27.11.2026; die Klemme selbst ist
  nicht nachgesehen, nach der Anleitung wäre es HV IN 3 mit 17.1.2 auf „PV-Einbindung aktiv“).
  Daraus folgt, was die Anforderung kann und was nicht:
  * Sie wirkt nur, **wenn die Anlage in Bereitschaft steht** (Seite 30). Läuft gerade ein
    Heizzyklus, ändert der Kontakt nichts. Die Ereignisstudie in `docs/K1_WIRKUNG.md` sollte
    Schließvorgänge deshalb danach trennen, ob die Maschine beim Schließen stand.
  * Sie hebt Sollwerte um einen Zuschlag, sie startet die Maschine nicht unmittelbar. Ab Werk
    steht der Zuschlag für Warmwasser (17.0.5, Kennung `762d`) auf **0 K**; dann bewirkt der
    Kontakt nichts. Die Seite „Regler“ liest den Wert schon.
  * Für eine Anlage mit Pufferspeicher nennt die Menütabelle einen zweiten Zuschlag: „Puffer
    OFFSET für PV-Einbindung“ (20.0.6, 0 bis 20 K, ab Werk 5 K), dazu die Speichersolltemperatur
    Heizen (20.0.3) und die Art des Sollwerts (20.0.7). Am Kombipuffer des Hauses dürfte dieser
    Wert der wirksame sein. Seine Kennung ist nicht bekannt und nicht gelesen.
  * Die Heizstäbe gibt der PV-Eingang nach der Anleitung nicht frei; das tut nur SG-Ready mit
    beiden Eingängen.
* Der dritte Zustand von SG-Ready wäre die stärkere Anforderung: Komforttemperatur statt der
  abgesenkten, nur mit dem Verdichter. Er braucht zwei Eingänge und einen zweiten Schaltkontakt.
* Wird nur einer der beiden Eingänge auf SG-Ready gestellt, meldet der Regler den Fehler 2 P9
  und die Funktion bleibt aus.
* Mit dem Zuschlag (`762d`, im Code `dhw_pv_delta_k`) wäre die Stärke der Anforderung selten und
  über den Bus einzustellen, das Ein und Aus aber über den Kontakt. Das ist der schonendste Weg:
  ein Wert im Speicher, geschaltet wird elektrisch.
* **Arbeit am Regler mit 230 V ist Sache einer Elektrofachkraft.**

## 5. Was der Regler anzeigt und der Bus bisher nicht liest

Die Diagnoseseiten 17.9 bis 17.15 (Seiten 42 bis 44) nennen Größen, die der Regler führt. Ihre
Kennungen stehen nicht in der Anleitung; sie sind am Bus zu finden, indem jemand die Seite am
Bediengerät öffnet, während das Add-on mitschreibt (so kam schon `hp_betrieb` zustande).

| Menü | Größe | Wofür |
|---|---|---|
| 17.9.0, 17.9.1 | Betriebsstunden und Zahl der Starts | Takten, unabhängig von der eigenen Auszählung |
| 17.9.2 bis 17.9.5 | Stunden und Starts des Heizstabs je Stufe | Heizstab bestätigen, Abschnitt 3 |
| 17.9.6 | Stunden im Abtauen | Abtauanteil |
| 17.9.8, 17.9.9 | Stunden Heizen und Warmwasser | Aufteilung der Kennlinie |
| 17.10.6 | Temperatur am Ausgang des Verflüssigers | Wärmerechnung ohne Verlust der Leitung |
| 17.11.6, 17.11.7 | Verdampfungs- und Verflüssigungsdruck | Kältekreis im digitalen Zwilling |
| 17.12.0 | Leistung des Umrichters in kW | Vergleich mit `hp_power` und dem Zähler |
| 17.12.2 | Sollmodulation des Verdichters | steht als `modulation` schon in `wp_vorgabe` |
| 17.12.7 | Öffnung des Expansionsventils | Kältekreis |
| 17.13.6 | Phasenstrom des Verdichters in mA | Die Zeile `verdichter_strom` rechnet in Zehntel Ampere; die Einheit ist zu prüfen. |
| 17.14.1 | Sollwert der Vorlauftemperatur | vermutlich `ziel` in `wp_vorgabe` |
| 17.15.2, 17.15.3 | Umschaltventile | bestätigt `ventil_ww` |
| 17.16.0 | die letzten zehn Fehler | Störungen ohne Blick aufs Bediengerät |

Die Fehlerlisten (Seiten 47 bis 49) liefern dazu die Wörter: Fehler des Innengeräts, Fehler
des Außengeräts (905 bis 957) und die Fehlercodes des Umrichters (17.11.1, 1 bis 53).

## 6. Der Bus selbst

* **Zwischen Innen- und Außengerät läuft Modbus, nicht der Bus des Bediengeräts** (Seiten 20
  und 24: drei Adern GND, A, B). Was das Add-on unter der Adresse `1e` liest, kommt vom
  Steuerteil der Wärmepumpe („Wärmepumpe TDM“ in der Geräteliste des Busses, Seite 36), der die
  Werte des Außengeräts weiterreicht.
* **Die Busversorgung ist knapp.** Ab drei Geräten kann der Fehler 420 „Überlastung
  Busversorgung“ auftreten (Seite 48). Der Adapter des Hauses darf den Bus deshalb nicht
  belasten. Tritt 420 nach dem Einbau auf, ist das die Ursache, nicht die Abfragen.
* Die Leitung zum Bediengerät darf höchstens 50 m lang sein und soll verdrillt oder geschirmt
  sein (Seite 12). Das gilt auch für die Leitung zum Adapter.
* Die Diagnoseseiten und das Menü 17 liegen hinter dem Fachmannzugang des Bediengeräts
  (Seite 30). Wer dort nur liest, verstellt nichts.

## 7. Grenzen der Maschine, an denen sich Werte prüfen lassen

Für die M-CRX; für die WH 09-11 erst nach dem Typenschild.

* **Einsatzbereich Heizen** (Seite 11): Vorlauf 20 bis 60 °C, unter −10 °C Außentemperatur
  fällt die Obergrenze bis auf 45 °C bei −20 °C; oberhalb von 15 °C draußen steigt die
  Untergrenze bis auf 33 °C bei 35 °C.
* **Durchfluss** (Seite 11): Der Durchflusssensor meldet „aus“ unter 280, 350 oder 490 l/h je
  nach Größe (4,7, 5,8 oder 8,2 l/min). `kennlinie.MIN_DURCHFLUSS` steht auf 2,0 l/min und läge
  damit unter jeder dieser Schwellen.
* **Abtauen** braucht 9 l Anlagenvolumen je kW (Seite 18); mit dem Puffer des Hauses ist das
  erfüllt.
* **Verdichter** 18 bis 120 Hz im Handbetrieb (17.7.5).

## Was daraus folgen sollte, in dieser Reihenfolge

1. **Typenschild ablesen** und den Typ in `SENSORIK.md` bestätigen oder berichtigen. Davon hängt
   ab, was aus den Abschnitten 3 und 7 gilt.
2. **Drei Lesarten am Bediengerät vergleichen** (Seite „Regler“ gegen das Menü): Betriebsart
   Warmwasser, Komfortstufe, Spartemperatur. Danach die Wörter und Grenzen in `regler.py`
   berichtigen, in Dashboard und App zugleich.
3. **Zuschläge ablesen:** 17.0.5 (Warmwasser) und 20.0.6 (Puffer) am Bediengerät, dazu 20.0.0,
   20.0.3 und 20.0.7. Sie bestimmen, wie viel eine Anforderung über K1 bewirkt. Steht beides
   niedrig, ist das der billigste Hebel im ganzen Haus: ein Wert, einmal eingestellt.
4. **Kennungen der Zähler suchen** (17.9 und 17.15 am Bediengerät öffnen, Add-on schreibt mit)
   und als Zeilen zum Lesen aufnehmen: Stunden des Heizstabs, Starts, Abtauen.
5. **Entscheidung des Hausherrn:** ob die Startzeit des Legionellenprogramms auf den Mittag
   gelegt wird und ob der Zuschlag bei Sonnenstrom stellbar werden soll.
