# Das Morning Briefing

Stand 13.11.2026. Rechnung und Zeilen in
`packages/hems-core/src/hems_core/planning/morgenbrief.py`, Versand und Vorschau in
`apps/api/src/dch_api/application/morgenbrief.py`, Endpunkte unter `/api/v1/push/morgenbrief`,
Einstellung auf der Seite `Technik → Mitteilungen`. Im Quelltext heißt es weiter `morgenbrief`;
auf dem Telefon und in der Oberfläche heißt es „Morning Briefing“.

## Was es ist

Eine Mitteilung am Morgen mit dem, was der Tag bringt, in vier kurzen Zeilen:

    Morning Briefing
    ☀️ 12 kWh erwartet, im Wesentlichen zwischen 10:15 und 14:15 Uhr
    ⚡ Ø 28 ct, am günstigsten 13:00 bis 15:00 Uhr (19 ct)
    🔥 62 kWh Wärme: Wärmepumpe 5 h, Ofen 3 h
    💶 Wärme: 2,10 € Strom; 1,40 € Pellets

**Die Form ist ein Nutzerwunsch vom 13.11.2026.** Vorher hieß die Mitteilung „Heute im Haus“ und
bestand aus drei ganzen Sätzen. Gewünscht: der Titel „Morning Briefing“, kürzere Texte, je Zeile
ein Zeichen vorweg; bei der Sonne die Menge mit dem Wort „erwartet“ und der Zeitraum als „im
Wesentlichen zwischen X und Y Uhr“; beim Strom eine Kennzahl des Preises; bei der Wärme eine kurze
Kennzahl und darunter die erwarteten Wärmekosten, geteilt in Strom und Pellets.

Das Briefing kommt von selbst, bevor jemand das Haus verlässt, und es gilt für den Rest des
heutigen Tages, nicht für die nächsten 24 Stunden: „morgen 02:00“ ist morgens um sieben keine
Auskunft für heute.

## Die vier Zeilen

| Zeile | Was sie sagt | Festlegung |
|---|---|---|
| ☀️ Sonne | Erwartete Erzeugung im Rest des Tages; „im Wesentlichen“ ist die kürzeste zusammenhängende Zeit, in der vier Fünftel davon anfallen. | Unter 2 kWh heißt es „kaum Sonne erwartet“, ohne Zeit. |
| ⚡ Strom | Mittlerer Preis im Rest des Tages und die günstigsten zwei Stunden am Stück mit ihrem mittleren Preis. | Zwei Stunden, weil so lange läuft, was sich verschieben lässt. Liegen billigster und teuerster Preis weniger als 4 ct auseinander: „kaum Schwankung“. |
| 🔥 Wärme | Wärmebedarf aus Heizen und Warmwasser, gegen den der Fahrplan rechnet, und wie lange Wärmepumpe und Ofen dafür laufen sollen. | Laufzeiten nur, wo der Optimierer geplant hat. Wo die Preisregel einspringt, steht kein Fahrplan. |
| 💶 Kosten | Was der Fahrplan für diese Wärme ausgibt: Strom der Wärmepumpe und Pellets. | Pellets stehen nur da, wenn es einen Ofenfahrplan gibt, dann auch mit 0,00 €. |

Eine Zeile, deren Zahlen fehlen, steht nicht im Briefing: ohne Preise keine ⚡-Zeile, ohne
Fahrplan des Optimierers keine Laufzeiten und keine Kosten.

**Strom und Pellets** (`strom_und_pellets` in `apps/api/src/dch_api/application/stove_planner.py`,
im Fahrplan je Viertelstunde als `planned_hp_cost_eur` und `planned_pellet_cost_eur`): Strom ist
der Strom der Wärmepumpe, gerechnet wie der Optimierer ihn zählt (Bezugspreis, oder die entgangene
Einspeisevergütung, wenn der erwartete Überschuss die ganze Maschine deckt). Pellets sind die
Pellets, die der Ofen verbrennt, zum eingetragenen Pelletpreis. **Die Summe der beiden ist nicht
die Zahl `planned_cost_eur` der Fahrplan-Seite**: dort zählt der Ofen mit seinem Eigenstrom und
abzüglich der angerechneten Raumwärme. Das ist die richtige Zahl für die Wahl zwischen Ofen und
Wärmepumpe und die falsche für die Frage, was die Pellets heute kosten. Der Eigenstrom des Ofens
(um 0,1 kW) fehlt im Briefing in beiden Zahlen.

Der Ausblick der Startseite (`apps/web/src/components/home/ausblick.ts`) benutzt dieselben
Schwellen für den Preis (zwei Stunden, 4 ct). Beim Sonnenfenster gehen die beiden seit dem
13.11.2026 auseinander: der Ausblick nennt die zwei besten Stunden, das Briefing die Zeit, in der
vier Fünftel der Energie anfallen.

| Versand | Wert | Warum |
|---|---|---|
| Uhrzeit | ab 07:00 Ortszeit, Versuche bis 09:00 | Fehlt der Fahrplan um sieben, kommt das Briefing, sobald er da ist. Nach neun ist es kein Morning Briefing mehr. |

## Einmal, auch nach einem Neustart

Der Dienst vermerkt den Versand als Ereignis `brief.morgen` mit dem Ortstag im Ereignis selbst
und liest ihn beim Start zurück. Ein Neustart um halb acht schickt deshalb keinen zweiten Brief.
Vermerkt wird erst, wenn es einen Brief gab: ein Morgen ohne Fahrplan ist kein versandter Brief.

Der Schalter steht in der gespeicherten Konfiguration (`morgenbrief`) und überlebt den Neustart.
Voreinstellung: eingeschaltet. Der Brief geht an alle Geräte, die für Mitteilungen angemeldet
sind; ein eigenes Abonnement gibt es nicht.

## Ob er ankommt

Am 12.11.2026 meldete der Nutzer: „Ich bekomme gar keine Push-Nachrichten auf mein Handy. Da war
doch ein Morning Briefing geplant.“ Der Brief war eingeschaltet. Was fehlte, war jede Auskunft darüber,
ob er verschickt wurde, an wen und mit welchem Ergebnis. Seitdem gilt:

* **Ohne angemeldetes Gerät gilt der Brief nicht als verschickt.** Vorher wurde der Tag auch dann
  vermerkt; wer sich um halb acht anmeldete, bekam an dem Morgen nichts mehr.
* **Das Ereignis `brief.morgen` hält fest, bei wie vielen Geräten er ankam** (`erreicht`,
  `geraete`). Die Seite sagt daraus „Zuletzt verschickt am …, angekommen bei 1 von 1 Gerät“ oder
  „Bisher ist kein Morning Briefing verschickt worden“. Nimmt kein Gerät ihn an, steht das da, und es
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
* **Der Absender muss eine Adresse sein, deren Endung es im öffentlichen Netz gibt.** Das war
  die Ursache: siehe den nächsten Abschnitt.

## Warum auf dem iPhone nichts ankam: der Absender

Jede Mitteilung weist sich beim Push-Dienst mit einer Absenderadresse aus (VAPID-Anspruch `sub`).
Bis zum 12.11.2026 stand dort der Platzhalter `mailto:duck-curve-home@example.invalid`. Das
Bildschirmfoto des Nutzers vom selben Tag zeigte „Dieses Gerät ist angemeldet“ und „Probe an 0
von 1 Geräten zugestellt“: angemeldet, aber abgelehnt.

**Messung am 12.11.2026** gegen Apples Push-Dienst (`web.push.apple.com`), mit Wegwerfschlüssel
und erfundenem Gerät, je einmal dieselbe Mitteilung mit anderem Absender. Wird der Absender
anerkannt, bemängelt die Antwort erst das erfundene Gerät (`400 BadWebPushToken`); wird er es
nicht, heißt sie `403 BadJwtToken`.

| Absender | Antwort |
|---|---|
| `mailto:…@example.invalid` (der alte Platzhalter) | 403 BadJwtToken |
| `mailto:…@example.test`, `…@example.local`, `…@localhost`, `…@haus.example` | 403 BadJwtToken |
| `https://localhost`, `https://haus.local`, `https://haus.invalid`, `https://haus.example` | 403 BadJwtToken |
| `https://haus.lan`, `https://haus.home`, `https://haus.internal`, `https://haus.localhost`, `https://haus.onion` | 403 BadJwtToken |
| `mailto:…@example.org`, `…@example.com`, `…@example.net`, `https://example.org` | angenommen |
| `https://192.168.178.20` (blanke Adresse) | angenommen |
| `https://haus.fritz.box`, `https://haus.home.arpa`, `https://abc.ts.net` | angenommen |
| `https://haus.example.org:8443`, `http://haus.example.org`, `https://haus` | gar nicht verschickt: die Signaturbibliothek (`py_vapid` 1.9.6) wirft |

Lesart: Apple nimmt nur Absender an, deren Endung im öffentlichen Netz vergeben ist, gleich ob
Postadresse oder `https`. Das ist eine Folgerung aus den Antworten, keine Auskunft von Apple, und
es gilt für den Tag der Messung. Andere Push-Dienste (Google, Mozilla) sind nicht gemessen.

Was daraus folgt (`apps/api/src/dch_api/application/push.py`):

* **Der Platzhalter heißt jetzt `mailto:duck-curve-home@example.org`.** `example.org` ist für
  Beispiele reserviert, gehört niemandem und wird angenommen.
* **Reihenfolge der Absender:** eine gesetzte Adresse (`DCH_PUSH_SUBJECT`), dann die eigene
  Adresse der Oberfläche, die das Gerät beim Anmelden nennt (`origin`, ohne Port), dann der
  Platzhalter. Was nach der Messung nicht taugt, wird vorab aussortiert (`tauglich`); eine
  untaugliche gesetzte Adresse wird übergangen und im Protokoll vermerkt.
* **Lehnt ein Push-Dienst einen Absender trotzdem ab, kommt der nächste dran**, und der
  abgelehnte wird bei diesem Dienst nicht wieder versucht. Die Liste der vergebenen Endungen
  steht nirgends im Code; ohne dieses Ausweichen fiele bei einem Haus mit ungewöhnlichem Namen
  wieder jede Mitteilung aus.
* **Gegenprobe am selben Tag** mit dem Versandweg des Dienstes selbst, in vier Lagen
  (Voreinstellung; Herkunft mit unbekannter Endung; Herkunft `.local`; alter Platzhalter von
  Hand gesetzt): jedes Mal kommt die Mitteilung am Absender vorbei bis zum erfundenen Gerät.

## Vorschau und Probe: immer das aktuelle Briefing

Nutzerwunsch 13.11.2026: Wer die Mitteilungen testet, soll „nicht einfach nur eine Testmitteilung“
bekommen, „sondern die aktuelle Meldung, die an diesem Tag rausgeschickt worden wäre,
beziehungsweise das aktuelle Morning Briefing“.

Seitdem gilt eine Regel für drei Stellen, die Vorschau auf der Seite, „Probe senden“ unter
Mitteilungen (`POST /push/test`) und „Jetzt senden“ beim Briefing (`POST /push/morgenbrief/senden`):
gezeigt und verschickt wird das Briefing von heute, wie es jetzt aussähe, also für den Rest des
Tages. Bleiben vom Tag weniger als zwei Stunden, ist es das von morgen früh, und die Seite sagt
das. Gibt es gar keines (kein Fahrplan), schickt „Probe senden“ den festen Satz von früher, denn
die Probe muss immer etwas schicken können; die Antwort sagt, dass es so war. Der Versand am
Morgen bleibt von jeder Probe unberührt.

Vorher zeigte die Seite nach neun Uhr das Briefing von morgen früh, und die Probe unter
Mitteilungen schickte „Probe: Mitteilungen kommen an.“

## Grenzen

* **Die Preise für morgen** kommen am frühen Nachmittag. Davor zeigt die Vorschau für morgen
  keinen Brief oder einen ohne Preiszeile.
* **Die Zeit der Sonne ist die Zeit der meisten erwarteten Erzeugung**, keine Zusage, dass
  Überschuss da ist: der Hausverbrauch geht nicht ein.
* **Eine Probe am Nachmittag ist nicht das Briefing von sieben Uhr.** Sie gilt für den Rest des
  Tages ab jetzt: weniger Sonne, weniger Wärme, weniger Kosten. Das Briefing von sieben lässt
  sich nachmittags nicht nachrechnen, weil der Fahrplan des Optimierers erst ab jetzt reicht.
* **Die Kosten sind das Versprechen des Fahrplans**, nicht die Rechnung. Was der Tag wirklich
  gekostet hat, steht in der Nachbetrachtung.
* **Die Uhrzeit ist fest.** Sieben Uhr steht im Quelltext, nicht in der Konfiguration.
* **In der Vorführung** gibt es Schalter und Vorschau, aber keinen Versand nach Zeitplan.
* **Geprüft am 13.11.2026** mit Tests und an der Vorführung (alle vier Zeilen, Probe mit dem
  Briefing als Inhalt). Der Absender wurde am 12.11.2026 gegen Apples Push-Dienst mit einem
  erfundenen Gerät geprüft. Auf einem echten Telefon ist das neue Briefing noch nicht angekommen.
