# ADR-0002 - Identität und Berechtigung (Anmeldung mit Passkey)

**Status:** angenommen und **umgesetzt** (23.11.2026) · **Datum:** 2026-11-20

## Kontext

Duck Curve Home hat heute **kein Benutzersystem**. Der Zugang läuft über zwei geteilte Tokens
(`DCH_KIOSK_TOKEN`, `DCH_GUEST_TOKEN`), die unter `/pair?token=…&name=…` gegen ein signiertes
HMAC-Cookie eingetauscht werden (`apps/web/src/lib/session.ts`); zwei Rollen, `owner` und `guest`,
durchgesetzt im BFF-Proxy (`apps/web/src/app/api/dch/[...path]/route.ts`). Die API selbst kennt nur
ein einziges statisches Token: wer `DCH_API_TOKEN` hat, darf alles (ADR-8 in
[`ARCHITECTURE.md`](../../ARCHITECTURE.md), dazu die Erklärung in
`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Zugang.swift`).

Die Grenzen davon sind benannt, aber sie werden mit jedem Schritt enger:

- Eine einzelne Sitzung lässt sich **nicht beenden**, ohne `DCH_SESSION_SECRET` zu wechseln - und
  damit jede andere Sitzung mit.
- Der Urheber eines Eingriffs ist ein **Gerätename**, kein Mensch. Am iPad im Flur kann jeder
  gestanden haben ([`docs/URHEBER.md`](../URHEBER.md)).
- Die iOS-App kann die Gastrolle nur **ausblenden**, nicht sperren: sie redet direkt mit dem Dienst,
  und das Token kann alles.
- Ein Gast-Link lässt sich nicht einem Gast entziehen, nur allen.

Der Hausherr möchte eine Anmeldung mit Passkey. Im Nachbarprojekt **DuckCurve** ist das gebaut und
im Browser geprüft: `duckcurve/auth/passkeys.py` (Bibliothek `webauthn`), Tabellen `passkeys` und
`passkey_schritte`, Wiederherstellungscodes, opake Sitzungstoken, dazu die Begründungen in
`docs/wiki/betrieb/passkeys.md`. Daneben gibt es dort ein Verfahren, das hier noch wichtiger wird:
die **Übergabe** an DuckCurve Horizon (`duckcurve/auth/dienst.py::uebergabe_ausstellen` /
`uebergabe_einloesen`) - ein Einmalcode mit kurzer Frist, den das Zielsystem gegen eine eigene
Sitzung tauscht.

Dazu zwei Festlegungen des Hausherrn, die den Horizont dieser Entscheidung bestimmen: Duck Curve
Home soll ein eigenes Ökosystem werden (13.11.2026, Q12 in [`docs/OPEN_QUESTIONS.md`](../OPEN_QUESTIONS.md)),
und im Kundenrollout wird es **kein Home Assistant** geben; Benutzer sollen zentral verwaltbar sein,
damit ein Beratungszugang möglich ist (20.11.2026). Die Erreichbarkeit, der Beitritt einer Box und
die Flottenpflichten stehen in [ADR-0003](ADR-0003-erreichbarkeit-und-flotte.md); hier geht es nur um
die Frage, **wer jemand ist und was er darf**.

## Die vier Teile, die nicht zusammengehören

In „Benutzerverwaltung" stecken vier Dinge. Erst getrennt lässt sich beantworten, was zentral werden
kann und was nicht:

| Teil | Wohin er gehört | Warum |
|---|---|---|
| **Identität** - Person, E-Mail, Passkeys, Wiederherstellung | zentralisierbar | Ein Passkey hängt an einer Domain, nicht an einer Instanz. Hier liegt der ganze Nutzen von „zentral" |
| **Berechtigung** - wer darf in *diesem* Haus was | immer lokal | Rollen sind Hausangelegenheit; zentral wäre es Fernverwaltung fremder Wohnzimmer |
| **Sitzung** - das Token, mit dem gearbeitet wird | immer lokal ausgestellt | Sonst sperrt ein Ausfall der Zentrale jeden aus seinem eigenen Haus |
| **Protokoll** - `urheber` in jeder Zeile | immer lokal | Der Anzeigename wird mitgeschrieben, nicht nachgeschlagen ([`docs/URHEBER.md`](../URHEBER.md)) |

## Optionen

| | A - lokal je Instanz | B - zentral, eigener Anmeldedienst | **C - lokal gebaut, zentral-fähig geschnitten** |
|---|---|---|---|
| Wo Personen und Passkeys liegen | in jeder Instanz eigen | in einem Dienst, Instanzen vertrauen ihm | heute in der Instanz, später verschiebbar |
| Mehrere Häuser | ein Konto je Haus | ein Konto für alles | ein Konto je Haus, bis die Zentrale kommt |
| Beratungszugang | Kunde legt einem Fremden von Hand ein Konto an | zentral erteilbar | erst lokal, dann zentral erteilbar |
| Ausfall der Zentrale | kein Begriff | niemand kommt in sein Haus | bestehende Sitzungen und lokale Anmeldung laufen weiter |
| Aufwand jetzt | gering | hoch (neuer Deployable, kritischster Dienst) | **gering, plus ein Schnitt** |
| Personendaten beim Betreiber | keine | alle Haushalte | erst keine, später nur Identität |
| Später teuer nachzuholen | RP-ID, Datenmodell | - | **nichts, wenn vier Festlegungen jetzt fallen** |

Option B hat den Reiz, DuckCurve als Anmeldedienst mitzubenutzen - dort ist alles fertig, Modulbegriff
inklusive. Dagegen spricht die Produktgrenze: ein privater Hausbesitzer bekäme ein Konto in der
Projektentwicklungsplattform einer Firma.

## Empfehlung

**Option C.** Der Nutzen einer Zentrale entsteht erst mit dem zweiten Haus, die Kosten sofort. Teuer
nachzuholen sind nicht die Dienste, sondern vier Festlegungen - und die kosten jetzt fast nichts.

## Entscheidung

**Option C: Identität zentralisierbar, Berechtigung und Sitzung immer lokal.** Heute ist die
„Zentrale" eine Tabelle in derselben Datenbank, kein Dienst. Dazu diese Festlegungen:

**1 · `DCH_PASSKEY_RP_ID = home.duckcurve.de`.** Eine RP-ID ist nicht änderbar, ohne alle
Passkeys zu entwerten, also ist das die eine Festlegung, die hier wirklich zählt.

> **Geändert am 23.11.2026.** Hier stand `duckcurve.de`, die registrierbare Domain, damit eine
> spätere zentrale Anmeldung unter `konto.duckcurve.de` dieselben Passkeys weiterverwenden
> könnte. Der Preis war in diesem Papier benannt - der Browser bietet dann auch die Passkeys von
> Duck Curve an - und zu billig veranschlagt: er war als Übergangsärgernis gedacht und ist in der
> Praxis ein Dauerzustand. Beide Passkeys tragen dieselbe E-Mail-Adresse und sehen im
> Auswahldialog gleich aus; der falsche wird abgewiesen, und man sieht ihm nicht an, welcher es
> war. Dagegen ist der eingetauschte Vorteil klein: jene Zentrale wäre ohnehin ein neuer
> Anmeldeweg, und einen Passkey neu anzulegen dauert zwei Minuten. Nebenbei widerspricht die
> gemeinsame RP-ID [ADR-0003](ADR-0003-erreichbarkeit-und-flotte.md), wo für die Box aus
> demselben Grund eine **getrennte** registrierbare Domain steht: RP-Bereiche, die sich
> überlappen, kosten mehr, als sie einbringen.

Was damit bewusst aufgegeben ist: Kommt die zentrale Anmeldung, legen die Leute dort neue
Passkeys an - ein Kopieren der Zeilen genügt dann nicht mehr. Für eine Handvoll Personen ist das
ein Nachmittag, nicht ein Projekt.

Was dadurch besser wird, über die Verwechslung hinaus: der RP-Bereich ist eng. Nur
`home.duckcurve.de` selbst kann Assertions für diese Passkeys anfordern - bei `duckcurve.de` wäre
es jede Subdomain gewesen.

**2 · Identität und Berechtigung sind zwei Tabellen,** von Anfang an: `person` (E-Mail, Name,
Passkeys) und `mitgliedschaft` (Person × `instanz_id` → Rolle). Bei einer Instanz hat die zweite
Tabelle eine Zeile je Person. Das ist die eine Vorleistung, die den Umzug billig macht: nur die
Identitätshälfte wandert, die Hausdaten bleiben liegen.

**3 · Ein Ausweis als Naht.** Wie `duckcurve/auth/kontext.py::Aufrufer`: unveränderlich, **einmal**
beim Auflösen des Tokens gebaut, danach nur weitergereicht; kein Endpunkt schlägt selbst nach, wer
fragt. Zwei Implementierungen hinter einer Schnittstelle - `lokal` (Zeremonie hier) und später
`zentral` (Einmalcode oder signiertes Dokument einlösen). Der Ausweis ist die **Quelle des
`Urheber`**: dann wird `art: person` ein Nebeneffekt, und `apps/api/src/dch_api/urheber.py` muss nicht
angefasst werden.

**4 · Die Anmeldung gehört in die API, nicht nur ins BFF.** Das kehrt ADR-8 um, und zwar notwendig:
die iOS-App redet direkt mit dem Dienst, und mit echten Personen muss der Dienst wissen, wer fragt.
Das BFF behält sein Cookie, aber darin steht künftig ein **opakes, widerrufbares Sitzungstoken** der
API statt eines signierten HMAC-Blobs (Begründung für opak statt JWT: `duckcurve/db/modelle.py`,
Klasse `Sitzung`). `DCH_API_TOKEN` bleibt nur für Maschinen übrig und bekommt eine eigene Rolle.

**Keine Passwörter.** Passkey plus Wiederherstellungscodes. Damit entfallen `passwoerter.py`,
`zweiter_faktor.py` (ein Passkey mit verlangter Nutzerprüfung *ist* der zweite Faktor), der Schalter
„nur noch Passkey" und jeder E-Mail-Versand. Eingeladen wird über einen Link, den der Hausherr auf
`/system/zugang` erzeugt - die Seite macht das heute schon, sie vergibt künftig Personen statt
Geräten.

**Drei Zugangsarten bleiben nebeneinander,** weil sie drei verschiedene Dinge sind (seit dem
23.11.2026 überholt - siehe Nachtrag unten: es gibt nur noch Personen):

| Art | Nachweis | Rolle | `urheber.art` |
|---|---|---|---|
| Person | Passkey, widerrufbar je Gerät | `hausherr`, `bewohner`, später `service` | `person` |
| Gerät | Pairing-Link wie heute, lange Frist | `anzeige` | `geraet` |
| Gast | Link mit Frist, kein Konto | `gast` | `geraet` |

Das Wand-iPad bekommt **keinen** Passkey. Ein Passkey behauptet eine Person, und am iPad im Flur kann
jeder gestanden haben; rückwirkend aus einem Gerät einen Menschen zu machen wäre eine Erfindung
(`urheber.py`). Und niemand soll für acht Stunden Zusehen ein Konto anlegen müssen. - *Auch dieser
Absatz ist mit dem Nachtrag hinfällig: der Mechanismus, der das Gerät von der Person trennte, taugte
nicht, und das Wand-iPad bekommt jetzt doch eine eigene Person.*

## Konsequenzen

- **ADR-8 beschreibt ab der Umsetzung nur noch den alten Stand.** Die Zeile in `ARCHITECTURE.md`
  verweist hierher.
- **Aus DuckCurve übernommen,** fast wörtlich: `auth/passkeys.py`, `auth/token.py` (opak, als SHA-256
  abgelegt), die Modelle `Passkey`, `PasskeySchritt`, `Sitzung`, `Zugangstoken`, und
  `tests/test_passkeys.py` - ein Software-Authenticator, der wirklich signiert, ist die halbe
  Sicherheit dieser Sache.
- **Nicht übernommen:** Organisationen, Modulbegriff, die vierstufige Rollenhierarchie, TOTP,
  Passwörter, Postausgang.
- **Neu in der API:** `dch_api/auth/` mit den Zeremonien, Endpunkte unter `/api/v1/auth/…`, Rollen an
  den Routern statt im Proxy. Alembic-Wanderung für fünf Tabellen.
- **Neu im Web:** eine Anmeldeseite mit `@simplewebauthn/browser`, `/system/zugang` wird von einer
  Token-Liste zu einer Personen- und Geräteliste, `lib/guard.ts` und `middleware.ts` fragen die API.
- **iOS:** Passkeys brauchen `webcredentials:home.duckcurve.de` in den Associated Domains und
  eine `apple-app-site-association` unter `https://home.duckcurve.de/.well-known/`. Seit die RP-ID
  auf dem eigenen Host steht (23.11.2026), liegt diese Datei beim web-Dienst dieses Repositories;
  vorher wäre es ein Eingriff in DuckCurveWebsite gewesen. Bis dahin bleibt die App beim
  Gerätetoken.
- **Zwei Passkey-Welten.** Die Box antwortet im Heimnetz unter einem eigenen Namen, und der liegt aus
  guten Gründen **nicht** unter der Konto-Domain (ADR-0003). Derselbe Passkey gilt daher nicht für
  Zentrale und Box. Gelöst wird das dort, nicht hier: die Box legt still einen zweiten,
  hausgebundenen Passkey an, sobald die Person mit gültiger Sitzung im eigenen Netz ist.
- **Die Rolle für den Support heißt `service`,** wie in [`docs/HAUSGERAET.md`](../HAUSGERAET.md)
  Abschnitt 7 eingeführt - dort für den Techniker vor Ort mit Geräte-PIN, hier für den Zugang aus der
  Ferne. Eine Rolle, ein Name; was sie darf und was nie, steht in [`docs/ZENTRALE.md`](../ZENTRALE.md).
- **Passkeys im Kioskbrowser funktionieren,** obwohl das Gerät lokal kein öffentliches Zertifikat hat:
  der Kiosk öffnet `http://localhost:3000`, und `localhost` gilt dem Browser als sicherer Kontext. Für
  jeden anderen Zugriff im Heimnetz gilt das nicht - siehe [ADR-0003](ADR-0003-erreichbarkeit-und-flotte.md).
- **Der heutige Zustand bleibt lauffähig.** Ohne `DCH_SESSION_SECRET` ist die Anmeldung aus, wie
  heute; das Kiosk-Token wird zum Gerätezugang, der Gast-Link bleibt, was er ist.

## Umgesetzt am 23.11.2026

Gebaut ist die Anmeldung mit Passkey samt Personenverwaltung und Einladung per E-Mail; die
Bedienung steht in [`docs/ZUGANG.md`](../ZUGANG.md). Drei Dinge weichen von diesem Papier ab, und
zwar bewusst:

**Die Rolle steht als Spalte an der Person, nicht in einer Mitgliedschaftstabelle.** Festlegung 2
verlangte zwei Tabellen von Anfang an. Bei genauerem Hinsehen ist das nicht die Stelle, die teuer
wird: eine `mitgliedschaften`-Tabelle später nachzuziehen ist eine **additive** Wanderung, die
`personen.rolle` ausliest und je Person eine Zeile schreibt - kein Datenverlust, kein Umbau der
Anwendung, weil zwischen Tabelle und Programm ohnehin der `Ausweis` steht. Teuer bleibt allein
die RP-ID, und die steht wie festgelegt auf der registrierbaren Domain. Der Nutzer wollte
ausdrücklich eine Single-Tenant-Lösung, die später aufgebohrt wird (23.11.2026); zwei Tabellen mit
je einer Instanz wären die Form ohne den Inhalt gewesen.

**Vier Rollen statt drei.** `gast` ist auch eine Rolle für Personen geworden, nicht nur ein Link:
ein Besuch, der länger bleibt, soll ein Gesicht haben dürfen. Und `service` heißt so wie in
[`docs/HAUSGERAET.md`](../HAUSGERAET.md) Abschnitt 7, nicht `berater`.

**Die Haustür brauchte keine eigene Regel.** Über diesen Dienst öffnet sie niemand - das macht der
Leser im Haus über die Bridge. Was hier liegt, ist ihr Protokoll, und das ist eine Akte und damit
ohnehin dem Hausherrn vorbehalten.

Nicht umgesetzt: die iOS-App meldet sich weiter mit dem Gerätetoken an. Passkeys brauchen dort
`webcredentials:home.duckcurve.de` und eine `apple-app-site-association` auf
`home.duckcurve.de` - seit der Änderung an Festlegung 1 eine Datei in diesem Repository.

## Nachtrag 23.11.2026: die Gerätepaarung ist ausgebaut

Dieses Papier hielt drei Zugangsarten nebeneinander - Person, Gerät, Gast - und begründete das
damit, dass ein Gerät keine Person ist. Das Argument stimmt; der Mechanismus dahinter taugte
nicht.

**Was daran faul war.** Eine Gerätesitzung entstand aus einem **stehenden Token in einer Adresse**
(`/pair?token=…`). Dieser Token stand im Klartext auf der Seite „Zugang" - also in jedem
Screenshot davon -, galt unbefristet, war beliebig oft einlösbar, und widerrufen ließ er sich nur,
indem man ihn für alle wechselte. Die Seite gab das selbst zu: „Der Ablauf begrenzt die Sitzung,
nicht den Link." Damit war der schwächste Teil des Zugangs ausgerechnet der mit den meisten
Rechten. Dazu kam ein Fehler, den die Form einlädt: Kiosk- und Gast-Token lassen sich auf denselben
Wert setzen, und dann vergibt der Gastlink Vollzugriff, weil zuerst gegen den Kiosk-Token geprüft
wird - genau das war am 23.11.2026 im Betrieb so eingestellt.

**Was stattdessen gilt.** Nur noch Personen mit Passkey. Eine Person darf an beliebig vielen
Geräten zugleich angemeldet sein - je Gerät ein Passkey und eine eigene Sitzungszeile, einzeln zu
beenden -, und eine benutzte Sitzung läuft nicht mehr ab: die Frist gleitet mit. Das war die
Aufgabe, für die es das Gerätecookie mit seinem halben Jahr gab.

**Was das kostet.** Das Gerät an der Wand bekommt eine eigene Person, deren Passkey auf einem iPad
im Flur liegt. Das ist schwächer als ein Passkey im Schlüsselbund eines Menschen und widerspricht
dem Satz, dass ein Gerät keine Person ist - der Name „Wandanzeige Flur" behauptet immerhin keinen
Menschen. Der Tausch ist trotzdem richtig: der Pairing-Link davor war schwächer. Und ein Gast
braucht jetzt eine Einladung; für acht Stunden Zusehen genügt kein Link mehr.

**Der erste Zugang** kam bisher über die Paarung. Ersatz ist `DCH_ERSTE_PERSON`: eine Umgebungs-
variable, die beim allerersten Start eine Person anlegt und ihren Einladungslink einmal ins
Protokoll schreibt. Ein offener Endpunkt wäre keiner.

**Offen bleibt das Display am Hausgerät selbst** (`deploy/haus`): es öffnet `http://localhost:3000`
und kam bisher über denselben Pairing-Link herein. Ein Passkey lässt sich in einem Chromium ohne
Plattform-Authenticator nicht anlegen. Die drei Wege stehen in `deploy/haus/README.md`, Abschnitt
„Zugang im Heimnetz"; entschieden ist keiner.

## Nachtrag 24.11.2026: das Passwort als zweiter Weg

**Entscheidung des Hausherrn:** Neben dem Passkey muss ein Passwort vergeben werden können, für
Leute, die keinen Passkey verwenden möchten. Es gibt beide Wege, im Dashboard und in der App.

Dieses Papier hatte das Passwort ausgeschlossen, mit dem Argument, dass es alles nach sich
zieht, was ein Passkey erspart: einen Hash, Regeln, eine Bremse, einen Rückweg. Das Argument
stimmt weiter, und der Passkey bleibt der empfohlene Weg. Es wiegt aber weniger als ein Haus, in
dem jemand nicht hereinkommt, weil er keinen Passkey will oder sein Gerät keinen kann.

**Was dazugekommen ist** (`dch_api/auth/passwort.py`, Migration `e7b3c9a52f1c`):

- **Der Hash.** Argon2id mit den Parametern der zweiten Empfehlung aus RFC 9106. Abgelegt ist
  nur der Hash; das Passwort steht in keiner Antwort und in keinem Protokoll.
- **Die Regeln.** Mindestens zwölf Zeichen, sonst keine Vorschrift. Das Passwort allein genügt,
  ohne zweiten Faktor.
- **Die Bremse.** Zehn Fehlversuche je Adresse in fünf Minuten, gemeinsam gezählt mit den
  Wiederherstellungscodes (`drossel.py`). Die Anmeldung mit Passkey bleibt davon unberührt.
- **Der Rückweg.** Ein neuer Link des Hausherrn ersetzt das Passwort, und die
  Wiederherstellungscodes gelten wie bisher. Einen Versand „Passwort vergessen" gibt es nicht:
  er wäre ein dritter Weg herein, der am Postfach hängt.
- **Die Wege.** Hinter dem Einladungslink wählt die Person Passkey oder Passwort. Angemeldet
  kann sie den jeweils anderen Weg ergänzen, das Passwort wechseln (mit dem bisherigen) oder es
  entfernen, solange ein Passkey bleibt. Mit Passwort darf auch der letzte Passkey gehen.

**Was sich damit verschlechtert und so dastehen soll:** Ein Lesezugriff auf die Datenbank
erlaubte bisher keine Anmeldung. Ein Passworthash lässt sich dagegen offline durchprobieren;
Argon2id und die Mindestlänge machen das teuer, nicht unmöglich. Und ein Passwort lässt sich
abfischen, ein Passkey nicht.

**Stand:** Gebaut ist der Dienst. Die Oberflächen in Dashboard und App folgen in einer eigenen
Änderung; bis dahin ist der Weg nur über die Schnittstelle erreichbar.

## Offene Punkte

- **Wie lange gilt eine Personensitzung?** Heute hält das Kiosk-Cookie ein halbes Jahr, damit die
  Wandanzeige Ruhe hat. Für Personen ist das zu lang und für Geräte richtig - also zwei Fristen, und
  die für Personen ist noch nicht gewählt.
- **Wiederherstellung ohne E-Mail-Versand.** Zehn Codes beim Anlegen, einmal angezeigt. Wer sie
  verliert und keinen zweiten Passkey hat, braucht einen Link des Hausherrn. Für den Hausherrn selbst
  bleibt der Notweg über die Umgebungsvariablen - das ist bewusst so und nur vertretbar, solange er an
  die Umgebung kommt.
- **Alte Protokollzeilen** behalten `art: geraet` und behaupten nie eine Person.
