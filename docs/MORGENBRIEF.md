# Der Morgenbrief

Stand 12.11.2026. Rechnung und Sätze in
`packages/hems-core/src/hems_core/planning/morgenbrief.py`, Versand und Vorschau in
`apps/api/src/dch_api/application/morgenbrief.py`, Endpunkte unter `/api/v1/push/morgenbrief`,
Einstellung auf der Seite `Technik → Mitteilungen`.

## Was er ist

Eine Mitteilung am Morgen mit dem, was der Tag bringt, in höchstens drei Zeilen:

    Heute im Haus
    Sonne: rund 12 kWh erwartet, am meisten von 11:30 bis 13:30.
    Strom: am günstigsten von 13:00 bis 15:00 (rund 19 ct), am teuersten um 18:00 (47 ct).
    Wärmepumpe: geplant von 12:00 bis 14:30.

Dieselben Auskünfte stehen im Ausblick der Startseite. Der Brief kommt von selbst, bevor jemand
das Haus verlässt, und er gilt für den Rest des heutigen Tages, nicht für die nächsten 24 Stunden:
„morgen 02:00“ ist morgens um sieben keine Auskunft für heute.

## Die Festlegungen

| Festlegung | Wert | Warum |
|---|---|---|
| Versand | ab 07:00 Ortszeit, Versuche bis 09:00 | Fehlt der Fahrplan um sieben, kommt der Brief, sobald er da ist. Nach neun ist es kein Morgenbrief mehr. |
| Ein Fenster | zwei Stunden am Stück | So lange läuft, was sich verschieben lässt: Waschmaschine, Spülmaschine, Trockner. |
| Preisfenster | erst ab 4 ct zwischen billigstem und teuerstem Preis | Darunter lohnt kein Verschieben; dann heißt es „nahezu gleich“. |
| Sonnenfenster | erst ab 1 kW im Mittel | Darunter ist „am meisten Sonne“ keine Empfehlung. |
| Kaum Sonne | unter 2 kWh am Tag | |
| Läufe der Wärmepumpe | nur was der Optimierer geplant hat, höchstens drei einzeln genannt | Wo die Preisregel einspringt, steht kein Fahrplan. |

Die ersten vier Werte sind dieselben wie im Ausblick der Startseite
(`apps/web/src/components/home/ausblick.ts`). Sie stehen an zwei Stellen, einmal für den Dienst und
einmal für die Oberfläche; wer einen ändert, ändert den anderen mit.

## Einmal, auch nach einem Neustart

Der Dienst vermerkt den Versand als Ereignis `brief.morgen` mit dem Ortstag im Ereignis selbst
und liest ihn beim Start zurück. Ein Neustart um halb acht schickt deshalb keinen zweiten Brief.
Vermerkt wird erst, wenn es einen Brief gab: ein Morgen ohne Fahrplan ist kein versandter Brief.

Der Schalter steht in der gespeicherten Konfiguration (`morgenbrief`) und überlebt den Neustart.
Voreinstellung: eingeschaltet. Der Brief geht an alle Geräte, die für Mitteilungen angemeldet
sind; ein eigenes Abonnement gibt es nicht.

## Ob er ankommt

Am 12.11.2026 meldete der Nutzer: „Ich bekomme gar keine Push-Nachrichten auf mein Handy. Da war
doch ein Morgenbrief geplant.“ Der Brief war eingeschaltet. Was fehlte, war jede Auskunft darüber,
ob er verschickt wurde, an wen und mit welchem Ergebnis. Seitdem gilt:

* **Ohne angemeldetes Gerät gilt der Brief nicht als verschickt.** Vorher wurde der Tag auch dann
  vermerkt; wer sich um halb acht anmeldete, bekam an dem Morgen nichts mehr.
* **Das Ereignis `brief.morgen` hält fest, bei wie vielen Geräten er ankam** (`erreicht`,
  `geraete`). Die Seite sagt daraus „Zuletzt verschickt am …, angekommen bei 1 von 1 Gerät“ oder
  „Bisher ist kein Morgenbrief verschickt worden“. Nimmt kein Gerät ihn an, steht das da, und es
  wird nicht jede Minute neu geschickt: der Push-Dienst lehnt aus demselben Grund wieder ab.
* **Jedes Gerät meldet sich einzeln an**, auf `Technik → Mitteilungen`. Auf iPhone und iPad geht
  das nur in der App vom Home-Bildschirm. Auf der Startseite des Telefons steht beim Hausherrn
  ein Hinweis, solange das Gerät nicht angemeldet ist; er lässt sich wegtippen.
* **Die Probe sagt je Gerät, was der Push-Dienst geantwortet hat**, mit Statuszahl und Grund
  (`details_de`). Dieselbe Auskunft steht in der Geräteliste (`GET /api/v1/push/geraete`): seit
  wann angemeldet, wann zuletzt angenommen, woran die letzte Mitteilung scheiterte. Der letzte
  Grund liegt im Arbeitsspeicher des Dienstes und ist nach einem Neustart leer bis zur nächsten
  Probe.
* **„Angenommen“ ist nicht „angezeigt“.** Der Dienst sieht nur, ob Apple, Google oder Mozilla die
  Mitteilung entgegengenommen haben. Ob das Gerät sie zeigt, entscheidet es selbst: Fokus, „Nicht
  stören“, Mitteilungen für die App abgeschaltet.
* **Ein angemeldetes Gerät meldet sich bei jedem Öffnen still noch einmal an.** Der Browser weiß
  nicht, ob der Dienst sein Abonnement noch kennt; nach einer neu aufgesetzten Datenbank hieße es
  sonst auf dem Telefon „angemeldet“, und es käme nie etwas an.
* **Der Absender ist die eigene Adresse der Oberfläche**, solange `DCH_PUSH_SUBJECT` nicht gesetzt
  ist. Das Gerät nennt sie beim Anmelden (`origin`), der Dienst merkt sie sich. Der frühere
  Platzhalter endet auf `.invalid`; Apples Push-Dienst prüft den Absender strenger als andere
  (Antwort `403 BadJwtToken`). Ob er diese Endung ablehnt, ist nicht belegt; mit einer echten
  Adresse stellt sich die Frage nicht.

## Die Vorschau

Die Seite zeigt den Brief, wie er als Nächstes verschickt würde: vor sieben den von heute,
zwischen sieben und neun den von jetzt, danach den von morgen früh. „Jetzt zur Probe senden“
schickt genau diese Vorschau; der Versand am Morgen bleibt davon unberührt.

## Grenzen

* **Die Preise für morgen** kommen am frühen Nachmittag. Davor zeigt die Vorschau für morgen
  keinen Brief oder einen ohne Preiszeile.
* **Das Sonnenfenster ist die Zeit der höchsten erwarteten Erzeugung**, keine Zusage, dass
  Überschuss da ist: der Hausverbrauch geht nicht ein.
* **Die Uhrzeit ist fest.** Sieben Uhr steht im Quelltext, nicht in der Konfiguration.
* **In der Vorführung** gibt es Schalter und Vorschau, aber keinen Versand nach Zeitplan.
* **Geprüft am 12.11.2026** mit Tests und an der Vorführung. Auf einem echten Telefon ist noch
  kein Brief angekommen. Warum im Haus am 12.11.2026 nichts ankam, ist von hier aus nicht zu
  sehen; die drei wahrscheinlichen Gründe in dieser Reihenfolge: das Telefon war nie angemeldet,
  der Dienst lief noch mit dem Stand vor dem Morgenbrief, oder der Push-Dienst lehnt ab. Die
  Probe auf der Seite unterscheidet jetzt die drei.
