# Der Morgenbrief

Stand 11.11.2026. Rechnung und Sätze in
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
* **Geprüft am 11.11.2026** mit Tests und an der Vorführung. Auf einem echten Telefon ist noch
  kein Brief angekommen.
