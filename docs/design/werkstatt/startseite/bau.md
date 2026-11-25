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
- Im Kit stehen noch die Sätze des früheren Ausblicks (`Ausblick.saetze` und was dazu gehört) und
  ihre Tests. Seit die Karte ein Bild ist, zeigt sie niemand mehr; ob das Ruhebild sie braucht, ist
  zu prüfen, bevor sie gehen.
