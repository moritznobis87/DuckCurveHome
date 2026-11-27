# Bau der neuen Startseite

**Entscheidung des Hausherrn vom 25.11.2026:** „Bühne und Uhr bauen und in den Einstellungen eine
Umschaltung zwischen beiden Varianten einbauen. Dann kann man beides nutzen.“

## Was daraus folgt

- Die Startseite bekommt zwei Bilder für ihre Mitte: `buehne` (Vorgabe) und `uhr`. Alles andere
  (Kopf, Satz, Wache, Puffer, Tageskurve mit den vier Zahlen, Schalter, Alfred) ist in beiden
  gleich. Mit der Bühne steht rechts „Nächste 24 Stunden“, mit der Uhr „Strom gerade“, weil der
  Ring die 24 Stunden selbst zeigt.
- Die Wahl gilt **je Gerät**: die Wand kann die Uhr zeigen und das Telefon die Bühne. Sie liegt im
  Browser unter `localStorage["dch-startbild"]` und in der App unter `@AppStorage("dch-startbild")`,
  so wie der Platz von Alfreds Ente. Das ist eine Annahme aus „dann kann man beides nutzen“; soll
  die Wahl für das ganze Haus gelten, gehört sie in den Dienst.
- Umgeschaltet wird auf der Seite „Einstellen“ in einer Karte „Startseite“.
- Der Sonnenbogen braucht Aufgang und Untergang. Der Dienst liefert beides nicht, aber der Fahrplan
  (`/plan`) deckt heute und morgen in Viertelstunden ab: Aufgang ist die erste, Untergang die letzte
  Viertelstunde des Tages mit mindestens 0,05 kW erwarteter Sonne. Dieselbe Schwelle wie `nacht`.

## Schritte

Jeder Schritt ist ein eigener Commit auf `claude/fervent-cori-oqlney` und für sich brauchbar.
Dashboard und App kommen in **einem** Pull Request (CLAUDE.md); er wird erst geöffnet, wenn beide
dasselbe zeigen.

| Nr. | Schritt | Stand |
|---|---|---|
| 1 | Kern: Rechnung für Bühne und Ring (`buehne.ts`, `stundenring.ts`, `startbild.ts`; im Kit `Startbuehne.swift`, `Stundenring.swift`, `Startbild.swift`) mit denselben Prüfwerten | fertig |
| 2 | Dashboard: neue Startseite mit der Bühne, an Wand, iPad und Handy angesehen | fertig |
| 3 | Dashboard: die Uhr und die Umschaltung auf „Einstellen“ (Karte „Startseite“ unter der Zustandskarte) | fertig |
| 4 | App: beide Bilder und die Umschaltung | geschrieben; Kit-Tests, Syntax und Textprüfung grün; ob die Oberfläche übersetzt, zeigt der Mac-Lauf der CI |
| 5 | Altes entfernen, Gleichstand prüfen, Pull Request | im Dashboard fertig: `FlowHero`, `FlowHandy`, `Rail`, `Ausblick` und 105 Stilregeln ohne Verwendung sind weg; App und Pull Request offen |

## Für die App mitzunehmen

- Die Zeile unter dem Satz ist jetzt ausformuliert: „Der nächste Lauf ist für 13:30 geplant.“ und
  „Entschieden um 12:38.“ (`JetztSeite.swift`, bisher „nächster geplanter Lauf um“ und „Stand“).
- Wer entscheidet, steht als Marke vor dieser Zeile; läuft die Wärmepumpe, steht eine zweite
  Marke „Wärmepumpe läuft“ daneben.
- Die Schalter, die eine Auswahl öffnen, tragen ihren Zustand als Wort: „läuft“ oder „aus“,
  „brennt“ oder „aus“, und der Zustand der Alarmanlage.
- „Nächste 24 Stunden“ zeigt auch die Brennzeiten des Pelletofens, als zweite Reihe Striche und
  als vierte Zeitspanne.

## Das Ruhebild (25.11.2026, nach dem Bau)

Der Hausherr nach dem Merge: „Je Gerät ist richtig so. Aber es läuft noch der Bildschirmschoner
auf dem alten Stand. Und bitte streiche im Bildschirmschoner diesen ewig langen Text. Wenn dann
nur ein ‚Wärmepumpe läuft‘.“

- Das Ruhebild zeigt unter der Uhr dasselbe Bild wie die Startseite, Bühne oder Uhr nach der Wahl
  des Geräts, mit dem Puffer und der Karte zum Bild, ohne Bedienung.
- Der Begründungssatz der Regelung ist gestrichen. Läuft die Wärmepumpe, steht eine Marke unter
  dem Datum. Der Befund der Wache bleibt, wenn eine Quelle schweigt.
- Am Fuß steht als fünfte Zahl, was die Sonne heute (am Tag) oder morgen (nachts) bringen soll.
  So bleibt erhalten, was der alte Schoner als „Heute erwartet“ und „Morgen Sonne“ gezeigt hat.
- Weg sind das Flussbild aus drei Kreisen, der kleine Sonnenbogen und die Abendzeilen zum
  Fahrplan, im Dashboard auch `fahrplan.ts` und `bogen` in `ambiente.ts`.

## Schlankere Bänder (25.11.2026, nach dem ersten Bild vom iPhone)

Der Hausherr mit einem Bild der App bei 8,1 kW Netzbezug und 8,6 kW Wärmepumpe: „Die lilane und
die orangene Linie sind etwas sehr dick, und vor allem überlappt die lilane das Piktogramm des
Masts.“

- Die Breite eines Bandes wächst jetzt mit der Wurzel der Leistung und endet bei 16 statt 30
  Pixeln (`bandbreite`, in Dashboard und Kit mit denselben Prüfwerten).
- Das Kabel setzt unter dem Mast um die halbe Bandbreite tiefer an (`bandkappe`), damit seine
  runde Kappe an der Erdkante endet.
- Zahl und Name von Netz und Speicher tragen in jeder Breite einen dunklen Hof, weil der
  Sonnenbogen durch sie läuft; in der App fehlte er ganz.
- In der App stehen die Marken unter dem Satz am Telefon in einer Reihe statt untereinander.
- `gebaut/buehne-handy-8kw.png` und `gebaut/buehne-wand-8kw.png` zeigen das Dashboard mit den
  Werten aus dem Bild des Hausherrn.

## Der Sonnenstand (26.11.2026, nach einem Bild vom iPhone um 09:17 Uhr)

Der Hausherr: „Irgendwas stimmt doch hier mit dem Sonnenstand nicht. Die Sonne steht gerade beim
Sonnenaufgang, wir haben aber schon 9:20 Uhr.“

**Die Ursache.** Die Enden des Bogens waren die erste und die letzte Viertelstunde, in der die
Ertragsprognose mehr als 50 Watt kannte. Das ist der Beginn der Erzeugung und nicht der
Sonnenaufgang. Gemessen am 26.11.2026 am Standort aus der Konfiguration:

| | Aufgang | Untergang | Stand der Sonne um 09:17 |
|---|---|---|---|
| Sonne am Standort, gerechnet | 08:09 | 16:36 | 13 % des Bogens |
| Im Bild bis dahin | 08:45 | 16:45 | 7 % des Bogens, also am Horizont |

**Die Änderung.**

- Der Dienst rechnet Aufgang und Untergang aus Datum und Standort
  (`packages/hems-core/src/hems_core/forecasting/sonne.py`, Verfahren der NOAA) und gibt sie im
  Fahrplan für heute und morgen mit (`PlanOut.sun`). Acht veröffentlichte Zeiten für Berlin und
  Frankfurt trifft die Rechnung auf die Minute (`test_sonne.py`).
- Dashboard und App nehmen diese Zeiten für den Bogen, die beiden Uhrzeiten an seinen Enden, für
  Tag und Nacht und für den Satz „Die Sonne geht um … auf.“ (`ambiente.ts`, `Ruhebild.swift`,
  dieselben Fälle in beiden Tests).
- Schickt ein älterer Dienst die Zeiten nicht mit, gilt wie vorher das Fenster der Erzeugung.
- `gebaut/sonnenlauf-handy.png` und `gebaut/sonnenlauf-wand.png` zeigen das Dashboard um 09:34 Uhr
  mit 08:09 und 16:36 an den Enden. `gebaut/sonnenlauf-nacht-handy.png` zeigt die Nacht; dafür
  sind die Zeiten des Tages im Browser verschoben, der genannte Aufgang von morgen ist echt.

**Was dabei auffiel, und seit demselben Tag behoben ist.** Die Ertragsprognose rechnete den
Sonnenstand mit einer einfacheren Formel ohne Zeitgleichung (`solar_elevation_deg`, und eine Kopie
davon im Vorführhaus). Gemessen am Standort:

| Tag | Sonnenmittag bis dahin | Sonnenmittag jetzt | Klarhimmel-Ertrag des Tages |
|---|---|---|---|
| 26.11.2026 | 12:36 | 12:23 | 10,95 kWh, jetzt 11,28 kWh |
| 11.02.2026 | 12:36 | 12:50 | 17,56 kWh, jetzt 18,25 kWh |
| 21.06.2026 | 13:36 | 13:37 | 64,80 kWh, jetzt 64,81 kWh |

Die erwartete Erzeugung lag damit im Spätherbst um knapp eine Viertelstunde zu spät und im
Februar um eine Viertelstunde zu früh. Die Höhe der Sonne steht jetzt neben den Sonnenzeiten in
`sonne.py`, mit derselben Deklination und Zeitgleichung; Prognose, Prognosebewertung und
Vorführhaus fragen dort. Die Mittagshöhen der Sonnenwenden stimmen auf ein Fünfzigstel Grad mit
der Geometrie überein (`test_sonne.py`).

## Die Kraft der Sonne (26.11.2026)

Der Hausherr: „Lass die Sonne bitte bei geringer Erzeugung ganz schwach und klein wirken, bei
starker Erzeugung groß und strahlend.“ Vorher war sie immer gleich groß, und ein trüber Morgen
mit 0,1 kW sah aus wie ein Sommermittag.

- **Eine Zahl für die Kraft.** `sonnenkraft` geht von 0 bis 1 und wächst mit der Wurzel der
  Erzeugung; bei 8 kW ist sie voll. Ein halbes Kilowatt ist damit ein Viertel der Kraft, zwei
  Kilowatt sind die Hälfte. Die Oberfläche kennt die Größe der Anlage nicht, darum ist die Skala
  fest wie bei den Bändern.
- **Was der Kraft folgt** (`sonnenbild`, in Dashboard und Kit mit denselben Prüfwerten): der
  Halbmesser der Scheibe (an der Wand 7 bis 22, am Telefon 6 bis 18), ihre Farbe von fahlem Hell
  zu Bernstein, ihr Leuchten, der weiche Schein um sie, der Lichtkegel zum Dach und der warme
  Schein des Himmels in der Ecke. Ab knapp einem Drittel der Kraft trägt sie einen Kranz aus
  zwölf Strahlen, der mit ihr länger wird.
- **Blass statt oliv.** Eine schwache Scheibe, nur durchscheinend auf den dunklen Himmel gelegt,
  wurde olivgrün. Sie liegt jetzt auf einem blassen Weiß und sieht aus wie eine Sonne hinter
  Dunst.
- `gebaut/sonnenkraft-wand.png` zeigt das Dashboard an der Wand bei 0,1, 2 und 8 kW,
  `gebaut/sonnenkraft-handy.png` am Telefon bei 0,5, 4 und 8 kW. Die Leistungen und der Stand
  der Sonne sind dafür im Browser gesetzt.

## Die Legende der Tageskurve (27.11.2026, nach einem Bild vom iPhone)

Der Hausherr mit dem Reiter „Morgen“ der App um 12:34 Uhr: „Die Legenden-Erklärung passt
überhaupt nicht zu der Grafik.“ Im Bild standen zwei gestrichelte Linien und eine durchgezogene.
In der Legende standen fünf Einträge, alle mit durchgezogenem Strich, zwei davon für etwas, das
nicht im Bild war.

- **Die Marken in der App sehen aus wie ihre Linien.** Die Ansicht zeichnete jeden Strich
  durchgezogen, gleich was der Eintrag sagte. Jetzt ist die Marke gestrichelt, wo die Linie
  gestrichelt ist, und trägt deren Farbe und Deckung. Das Dashboard konnte das schon.
- **Die Legende nennt, was im Bild steht.** Strompreis und Preistief stehen nur da, wenn ein
  Preis oder ein Band im Bild liegt; die erwartete Wärmepumpe nur, wenn ihre Linie da ist. Die
  Preise für morgen veröffentlicht die Börse gegen 13 Uhr; bis dahin sagen das die Zahlen des
  Tages („Preise kommen gegen 13 Uhr“), und die Legende nennt die Preise nicht. Sonne, Prognose
  und Haus bleiben an jedem Tag stehen.
- Die Regel steht einmal je Seite, im Dashboard in `tageslegende.ts` und im Kit in
  `Kurvenlegende.swift`, mit denselben sieben Fällen in beiden Tests.
- Im Dashboard am Telefon sind dabei drei Fehler derselben Karte behoben: Das Wort unter
  „Wärme erwartet“ lief aus der Karte, die mittlere Marke der Preisachse stand als „22.5 ct“
  abgeschnitten da, und die letzte Uhrzeit der Zeitachse war am Rand abgeschnitten.
- `gebaut/legende-morgen-handy.png` zeigt das Dashboard am Telefon mit dem Reiter „Morgen“ vor
  13 Uhr.

## Bilder der gebauten Seite

`gebaut/` zeigt die Startseite des Dashboards im Demo-Betrieb am 25.11.2026: Bühne und Uhr, je an
der Wand (1280 × 800) und am Handy (390 breit, die ganze Seite). Der runde Knopf unten links ist
die Anzeige des Entwicklungsservers und gehört nicht zur Seite.

## Was beim Bau entschieden wurde

- **Der Puffer zeigt weiter dasselbe Glas wie überall.** Der Entwurf hatte eine eigene Säule. Der
  Hausherr hat am 14.11.2026 festgelegt, dass der Speicher überall gleich aussieht und am Telefon
  liegt; darum steht in der Karte an der Wand das Glas der Anlage (`PufferGlasBild`), und am
  Telefon liegt es mit den Zahlen unter ihren Fühlern.
- **Die Unterschiede zwischen Dashboard und App** stehen in `docs/GLEICHSTAND.md` unter „Form, die
  sich unterscheidet“: der Puffer liegt in der App auch an der Wand, die untere Reihe der Wand
  hat in der App keine Karten, und der Lüfter dreht sich nur im Dashboard.

## Was offen bleibt

- Das Ruhebild (Ambiente) bleibt, wie es ist.
- In der App wird nichts gesehen: SwiftUI baut nur der Mac-Lauf der CI.
- Im Kit steht noch Rechnung ohne Verwendung in der App, mit ihren Tests: die Sätze des früheren
  Ausblicks (`Ausblick.saetze` und was dazu gehört), die Zeilen zum Fahrplan (`Fahrplan.zeilen`,
  `Planzeile`) und der Bogen des alten Ruhebilds (`Ruhebild.bogen`). Das Dashboard hat seine
  Gegenstücke schon entfernt; im Kit ist das eine eigene Änderung.
