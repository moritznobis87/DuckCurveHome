# Änderungen

Diese Datei zeigt Home Assistant im Update-Dialog: wer das Add-on aktualisiert, liest hier, was er
sich holt. Gepflegt wird sie von jetzt an mit jeder Anhebung von `version` in `config.yaml` --
Home Assistant bietet ein Update nur an, wenn diese Nummer steigt, und ohne Eintrag hier steht im
Dialog nur eine Zahl.

Die Einträge bis einschließlich 0.15.1 sind **nachträglich rekonstruiert**, aus zwei Quellen:

- Der Fassungsgeschichte von `config.yaml` im Repository (`git log -p -- addons/duckcurve_bridge/config.yaml`)
  samt den Botschaften der Commits, die die Nummer angehoben haben. Diese Quelle reicht nur bis zum
  13.11.2026 zurück: der Arbeitsbaum ist eine verkürzte Kopie (`git rev-parse --is-shallow-repository`
  sagt `true`), und in ihrem ältesten Commit (07.11.2026) stand `version` bereits auf 0.13.1. Darum
  trägt keine Fassung bis 0.13.1 ein Datum -- es ist hier nicht zu belegen, und geraten wird es nicht.
- Den Erwähnungen einzelner Fassungen in `DOCS.md`. Sie sind vom Autor selbst geschrieben und
  beschreiben, was eine Fassung dem Haus gebracht hat. Für alles vor 0.14.0 sind sie die einzige
  Quelle. Als Marke „(ab X.Y.Z)“ stehen sie nur bei elf der hier genannten Fassungen; die übrigen
  sind in laufendem Text belegt („Ab 0.5.0 lädt die Bridge …“, „ab 0.12.1 selbst weg“, „(0.13.1:
  `tree`)“). Jeder Eintrag dieser Datei hat eine solche Stelle -- erfunden ist keiner.

**Zwei Fassungen fehlen mit Absicht:** über 0.1.0 und 0.4.0 sagt keine der beiden Quellen etwas.
Lieber eine Lücke als eine erfundene Zeile.

## 0.15.1 - 2026-11-23

- Die Uhrzeit in der Statuszeile der Haustür („Geöffnet für … um 19:42:07“) steht jetzt in Ortszeit.
  Bis dahin stand sie in der Zeitzone des Containers, und wer abends nachsah, wann die Tür aufging,
  verglich mit einer falschen Zahl.

## 0.15.0 - 2026-11-15

- Die Bridge kann Einstellungen des Reglers der Wärmepumpe stellen: der Dienst schickt
  `ebus:<Schlüssel>:stellen` mit einem Wert, die Bridge macht daraus das Thema
  `ebusd/energymgr/e_<name>/set` und lässt die Einstellung anderthalb Sekunden später neu lesen.
- Gestellt wird nur, was in der Zuordnung unter `energymgr/e_…` steht; einen Messwert wie den
  Vorlauf lehnt die Bridge ab. Ob überhaupt etwas hinausgeht, entscheidet das Add-on
  „Duck Curve eBUS“ mit seinem Schalter `stellen`, und der ist ab Werk aus.

## 0.14.5 - 2026-11-14

- Der Betriebszustand der Wärmepumpe kommt zusätzlich aus `heatpump_mode`, das das Bediengerät alle
  zehn Sekunden abfragt; die Bridge liest das Wort als dieselbe Zahl, die der Bus sonst meldet.
  Anlass war der 14.11.2026: die Seite zeigte „steht“ und null Hertz, während die Maschine lief.

## 0.14.4 - 2026-11-14

- Schalter vom Bus (`on`/`off`) werden als 1 und 0 gelesen. Damit kommen Heizanforderung und
  Raum-Sollwert der Zone 1 sowie die Vorgaben des Reglers an die Maschine überhaupt an.

## 0.14.3 - 2026-11-14

- Die eigene Datei `/config/duckcurve/entities.yaml` **ergänzt** die Zuordnung aus dem Repository,
  statt sie zu ersetzen: was in ihr steht, gilt; was nur im Repository steht, kommt hinzu. Zuvor
  hatte die Datei Vorrang, und weil in ihr der Bus der Wärmepumpe fehlte, kam vom Bus nichts an.
  Wer das alte Verhalten will, schreibt `ersetzt_repository: true` in die Datei.
- Woher die Zuordnung stammt, meldet die Bridge jetzt als Zustand der Quelle `zuordnung`
  (`repository`, `datei+repository`, `datei+zwischenspeicher`, `zwischenspeicher`, `datei`).

## 0.14.2 - 2026-11-14

- Kommt kein Buswert an, sagt die Bridge, wo es hängt: 90 Sekunden nach dem Start und dann alle fünf
  Minuten meldet sie die Lage des Busses (`broker_getrennt`, `kein_wort`, `verstummt`, `kein_signal`,
  `nicht_zugeordnet`, `nur_mitlesen`, `abgeschaltet`, `ok`). Die Seite Technik → Wärmepumpe macht
  daraus einen Satz, dieselbe Zeile steht im Protokoll unter `ebus lage`. Zuvor stand am 14.11.2026
  an jedem Buswert ein Fragezeichen und nirgends ein Grund.

## 0.14.1 - 2026-11-13

- Eine Zuordnung kann eine Bedingung auf die Kennung tragen (`"=76 9e"`): der Wert geht nur weiter,
  wenn in der Liste wirklich diese Kennung steht. Anlass war eine Liste mit anderer Zusammensetzung,
  die ohne jede Fehlermeldung falsch gelesen wurde.

## 0.14.0 - 2026-11-13

- Die Wärmepumpe wird über den eBUS gelesen: ein Eintrag mit `kind: ebusd` in der Zuordnung, und die
  Bridge holt die Werte am Mosquitto-Broker ab, wo das Add-on „Duck Curve eBUS“ sie ablegt -- wie bei
  den Shellys, ohne Home Assistant.
- Fehlt ein Buswert, springt Home Assistant ein, sofern der Schlüssel auch unter `sensors` steht.
- Nur frische Werte gehen weiter, der Marker für einen fehlenden Fühler (3276,7) wird verworfen, und
  jeder Name, den der Bus meldet, steht einmal im Protokoll (`ebusd meldet name=…`) -- daraus wird
  die Zuordnung gemacht.

## 0.13.1

- Der Hausplan kennt die Art `tree`. Das Schema steckt im Abbild des Add-ons: kommt im Plan eine Art
  von Eintrag vor, die diese Fassung nicht kennt, lehnt sie die ganze Datei ab, auch wenn der Dienst
  sie längst kennt.

## 0.13.0

- Hausplan: neben der Entity-Zuordnung liegt eine Datei, die das Haus als Modell beschreibt. Der
  Bereich Haus der Anzeige zeichnet daraus beide Geschosse -- Räume in ihrer Temperatur, offene
  Heizkreise, Fenster und Türen mit Kontakt, Puffer, Wärmepumpe und Wallbox mit ihren Zahlen.

## 0.12.1

- Steht im Feld `alarm_entity` versehentlich die ganze Zeile (`alarm_entity: alarm_control_panel.…`),
  schneidet die Bridge den Namen selbst weg. Zuvor ging der ganze Text als Ziel an Home Assistant,
  und der Fehler zeigte sich erst beim Druck auf den Knopf, nicht beim Einrichten.

## 0.12.0

- Ein unveränderter Wert ist kein Schweigen mehr: was die Bridge beim regelmäßigen Nachlesen aller
  Zustände aus Home Assistant bekommt, gilt als eben bestätigt und damit als frisch. Zuvor alterten
  genau die Werte weg, die stillstehen sollen -- die PV-Leistung nachts, ein leerer Speicher --, und
  der Bilanz fehlte die Erzeugungsseite.

## 0.11.0

- Der Zustand der Alarmanlage wird gelesen, über einen Eintrag `kind: alarm` in der Zuordnung, und
  als Zahl weitergegeben (0 unscharf bis 4 ausgelöst).
- Mit `alarm_entity` und `alarm_arm_enabled` lässt sich die Anlage aus der Anzeige scharf schalten,
  „Zu Hause“ oder „Unterwegs“. Unscharf schaltet die Bridge nie, und das ist kein Versehen: die
  Wandanzeige hängt in der Küche, ihr Zugang ist schwächer als ein Code am Bedienteil.

## 0.10.0

- Mit Controme-Zugangsdaten wird aus der Anzeige eine Bedienung: auf der Räume-Seite lässt sich die
  Solltemperatur eines Raums in halben Grad verstellen, dauerhaft, in Grenzen von 5 bis 30 Grad. Die
  Bridge schickt sie an denselben Endpunkt wie Contromes eigene Oberfläche und fragt sofort danach
  neu ab, damit die Anzeige nicht zwei Minuten den alten Wert zeigt.

## 0.9.0

- Die Einzelraumregelung wird mitgelesen: die Bridge fragt den Controme-Mini-Server im Heimnetz ab
  und liefert je Raum die gemessene Temperatur, den Sollwert, den Offset, die Luftfeuchte und die
  Stellung der Ventile am Heizkreisverteiler; Namen, Etagen und die Zahl der Heizkreise gehen als
  Raumliste mit. Gestellt wird in dieser Fassung nichts.

## 0.8.0

- Die Bridge kann die Haustür öffnen, wenn der UniFi-Access-Reader ein freigegebenes Gesicht
  erkennt. Die Kette bleibt im Heimnetz: Reader, Konsole, Bridge, Schloss.
- Ohne `door_enabled` läuft der Dienst im Beobachtungsbetrieb und rührt das Schloss nicht an: er
  protokolliert jeden Zutritt mit Tür, Person und Verfahren, und aus diesen Zeilen werden die drei
  Freigabelisten (`door_doors`, `door_actors`, `door_methods`) gefüllt. Freigegeben ist
  ausschließlich, was in ihnen steht; eine leere Liste heißt niemand, nicht alle.

## 0.7.1

- `mcz_allow_control` steht ab Werk auf `true`. Wer 0.7.0 schon installiert hat, muss die Option
  einmal von Hand umstellen: Home Assistant übernimmt eine geänderte Vorgabe nicht nachträglich.

## 0.7.0

- In dieser Fassung stand `mcz_allow_control` ab Werk auf `false`. Mehr ist über sie nicht
  überliefert; `DOCS.md` nennt sie nur als die Fassung, deren Vorgabe 0.7.1 geändert hat.

## 0.6.0

- Der Pelletofen (MCZ mit Maestro-Modul) wird direkt über seinen WebSocket gelesen, ohne Cloud und
  ohne zusätzlichen Dienst: Schneckendrehzahl, Rauchgastemperatur, Vor- und Rücklauf des Ofenkreises,
  Pumpenmodulation und der eigene Pufferfühler des Ofens. Erst damit ist zu trennen, welcher Anteil
  einer Pufferladung von der Wärmepumpe kam und welcher vom Ofen.

## 0.5.0

- Die Bridge lädt die Entity-Zuordnung beim Start selbst aus dem Repository (Option `entities_url`).
  Eine Änderung dort wirkt nach einem Neustart des Add-ons, ohne dass jemand eine Datei ins Haus
  kopiert. Die Antwort liegt unter `/data/entities.cache.yaml`, damit die Bridge auch ohne Internet
  startet.

## 0.3.0

- Auch die Shellys der Generationen 2 und 3 (Plus und Pro) werden am Broker gelesen.

## 0.2.0

- Die Shellys liefern ihre Werte direkt an den lokalen Mosquitto-Broker, und die Bridge liest sie
  dort ab, ohne den Umweg über Home-Assistant-Integration und -Entitäten. Das ist seitdem der
  Standardweg; Home Assistant bleibt für die übrigen Entitäten und die Schalter zuständig.
