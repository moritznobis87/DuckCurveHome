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
| 1 | Kern: Rechnung für Bühne und Ring (`buehne.ts`, `stundenring.ts`, `startbild.ts` und ihre Gegenstücke im Kit) mit denselben Prüfwerten | offen |
| 2 | Dashboard: neue Startseite mit der Bühne, an Wand, iPad und Handy angesehen | offen |
| 3 | Dashboard: die Uhr und die Umschaltung auf „Einstellen“ | offen |
| 4 | App: beide Bilder und die Umschaltung | offen |
| 5 | Altes entfernen (`FlowHero`, `FlowHandy`, `Rail`, `Ausblick` als Sätze, alte `.home-*`-Regeln), Gleichstand prüfen, Pull Request | offen |

## Was offen bleibt

- Das Ruhebild (Ambiente) bleibt, wie es ist.
- In der App wird nichts gesehen: SwiftUI baut nur der Mac-Lauf der CI.
