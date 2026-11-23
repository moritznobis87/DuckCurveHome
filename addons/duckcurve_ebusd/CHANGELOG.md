# Änderungen

Diese Datei zeigt Home Assistant im Update-Dialog: wer das Add-on aktualisiert, liest hier, was er
sich holt. Gepflegt wird sie von jetzt an mit jeder Anhebung von `version` in `config.yaml` --
Home Assistant bietet ein Update nur an, wenn diese Nummer steigt, und ohne Eintrag hier steht im
Dialog nur eine Zahl.

Die Einträge bis einschließlich 0.5.0 sind **nachträglich rekonstruiert**, aus der Fassungsgeschichte
von `config.yaml` im Repository (`git log -p -- addons/duckcurve_ebusd/config.yaml`), den Botschaften
der Commits, die die Nummer angehoben haben, und den Marken „(ab X.Y.Z)“ in `DOCS.md`. Dieses Add-on
ist jünger als der verkürzte Arbeitsbaum, in dem rekonstruiert wurde: seine ganze Geschichte von der
ersten Fassung an liegt in diesen Quellen, darum trägt hier jeder Eintrag ein Datum.

Was vom Add-on am Haus hängt, also der Adapter am Bus und die Wärmepumpe selbst, steht in keiner
dieser Quellen. Wo eine Fassung nur am Übungsadapter geprüft ist und nicht an der echten Maschine,
sagt es `DOCS.md` an der jeweiligen Stelle.

## 0.5.0 - 2026-11-15

- Mit `stellen: true` kann das Add-on vierzehn Einstellungen des Reglers ändern und nichts sonst:
  Steilheit und Verschiebung der Heizkurve, kleinster, größter und fester Vorlauf, Einfluss der
  Raumtemperatur, Raumtemperatur Tag und Nacht, Warmwasser Komfort- und Spartemperatur, Betriebsart
  des Warmwassers, Legionellenprogramm, Heizbetrieb und Flüstermodus.
- **Ab Werk aus.** Dass dieses Add-on etwas an der Heizung verändern kann, schaltet jemand bewusst
  ein. Eingeschaltet bleiben alle fremden Zeilen zum Stellen aus der Bus-Beschreibung entfernt (67 in
  der geprüften Fassung), und das Startskript startet nicht, wenn danach nicht genau vierzehn Zeilen
  zum Stellen übrig sind.
- Gestellt wird über die Seite „Regler“ von Duck Curve Home, über den Dienst und die Bridge ab 0.15.0.

## 0.4.0 - 2026-11-15

- Das Add-on fragt zwölf Einstellungen des Reglers ab, jede etwa alle zehn Minuten: Steilheit und
  Verschiebung der Heizkurve, kleinster, größter und fester Vorlauf, Art der Vorlaufregelung,
  Raumtemperatur Tag und Nacht, Warmwasser Komfort- und Spartemperatur, Betriebsart des Warmwassers,
  Flüstermodus. Die Seite „Regler“ zeigt sie mit Zeitpunkt und Kennung.
- Verstellt wird damit nichts; die Zeilen zum Stellen bleiben aus der Bus-Beschreibung entfernt. Die
  Kennungen stammen aus der Liste einer verwandten Anlage und sind im Haus nicht bestätigt -- die
  Seite ist dafür da, sie mit dem Bediengerät zu vergleichen.

## 0.3.1 - 2026-11-15

- Betriebszustand und Verdichterfrequenz fragt das Add-on jetzt selbst ab. Beide kamen nur aus einer
  Liste, die der Regler der Maschine selten abfragt; am 15.11.2026 fehlte die Frequenz nach einem
  Neustart der Bridge ganz. Die Zeile liest weiter mit, wenn der Regler von selbst fragt.

## 0.3.0 - 2026-11-14

- Vier Werte, die nie von selbst über den Bus gehen, fragt ebusd jetzt reihum ab: Umschaltventil,
  elektrische Zusatzheizung, Strom des Verdichters und Drehzahl des Lüfters (Option `abfragen`, je
  zehn Sekunden eine Frage).
- Abfragen heißt senden, also ohne `--readonly`. Damit daraus kein Weg zum Verstellen wird, entfernt
  das Startskript bei jedem Start jede Zeile zum Stellen aus einer Arbeitsfassung der
  Bus-Beschreibung und startet nicht, wenn eine übrig bleibt; `--enablehex` und `--enabledefine`
  lehnt es mit `read_only` ab.
- Behoben: `read_only: false` blieb bisher wirkungslos, weil `jq` den Wert `false` wie „nichts“
  behandelt.
- Behoben: fremde Zeilen mit denselben Kennungen weichen jetzt den eigenen -- ebusd nimmt eine
  Kennung nur einmal an, und vorher gewann die falsche.

## 0.2.3 - 2026-11-14

- Zwei eigene Zeilen dazu: die Kennung 1b45 neben der des Heizstabs und die Vorgaben des Reglers an
  die Maschine (cd46, 6a47). Ihre Bedeutung ist teils offen, die Werte werden aber schon geführt.

## 0.2.2 - 2026-11-14

- Die Betriebsart des Reglers, die er im Rundruf sendet (Kennung c94b), wird mit zwei eigenen Zeilen
  gelesen. Bestätigt sind davon 0 für Bereitschaft und 2 für Heizen; die übrigen Kennzahlen bleiben
  Zahlen. Die Ventilstellung selbst sendet der Bus nicht.

## 0.2.1 - 2026-11-13

- Eigene Zeile `hp_betrieb` (Außentemperatur, Durchfluss, Betriebszustand, Verdichterfrequenz) und
  `speicher_info` (Speichertemperatur des Reglers).
- `system_temps` legt die Kennung vor dem zweiten Wert offen, damit die Bridge prüfen kann, ob sie
  wirklich die erwartete Liste liest.

## 0.2.0 - 2026-11-13

- Eigene Zeilen für die Wärmepumpe dieses Hauses (`aerotop_split.csv`): Leistungsaufnahme, Sauggas
  und Heißgas, Außentemperatur im Rundruf, zwei Temperaturen des Reglers und die Hauptpumpe. Sie sind
  aus dem Protokoll des Hauses gelesen, an dessen Telegrammen geprüft und lesen nur mit.

## 0.1.0 - 2026-11-13

- Erste Fassung. Das Add-on verpackt ebusd 26.1, fertig gebaut aus dem Abbild seines Autors, lädt die
  Bus-Beschreibung der Ariston-Gruppe in einer festgelegten Fassung mit Prüfsumme und startet ebusd
  nur lesend. Die Werte gehen als JSON auf den Mosquitto-Broker, wo die Duck Curve Bridge sie ab
  0.14.0 abholt.
- Gewollt war ausdrücklich kein fremdes Add-on und kein weiterer Dienst, nur der Broker, der im Haus
  ohnehin läuft.
