# Zugang: wer hereinkommt, womit, und was er darf

Stand 24.11.2026. **Gebaut.** Die Entscheidungen dahinter stehen in
[ADR-0002](decisions/ADR-0002-identitaet-und-berechtigung.md); das Zielbild für mehrere Häuser in
[ZENTRALE.md](ZENTRALE.md) und [ADR-0003](decisions/ADR-0003-erreichbarkeit-und-flotte.md). Diese
Seite beschreibt, was es heute gibt und wie man es bedient.

## Kurz gesagt

- **Eine Person meldet sich mit einem Passkey an, oder mit E-Mail-Adresse und Passwort.** Der
  Passkey ist der empfohlene Weg: nichts zum Abtippen, kein zweiter Faktor daneben, denn ein
  Passkey mit verlangter Nutzerprüfung ist Besitz und Merkmal zugleich. Das Passwort gibt es
  seit dem 24.11.2026 für Leute, die keinen Passkey verwenden möchten (ADR-0002, Nachtrag).
  Beide Wege gibt es im Dashboard; die App meldet sich mit E-Mail-Adresse und Passwort an, der
  Passkey folgt dort noch (`docs/GLEICHSTAND.md`).
- **Es gibt keinen Link mehr, der Zugang vergibt.** Bis zum 23.11.2026 stellten zwei stehende
  URL-Tokens Gerätesitzungen aus - einer für Vollzugriff, einer für Gäste. Sie standen im Klartext
  auf dieser Seite, galten unbefristet, waren beliebig oft einlösbar und ließen sich nur für alle
  zugleich widerrufen. Ausgebaut (ADR-0002, Nachtrag).
- **Eine Person darf an beliebig vielen Geräten zugleich angemeldet sein:** je Gerät ein Passkey
  und eine eigene Sitzung in `person_sitzungen`, einzeln zu beenden.
- **Eine benutzte Sitzung läuft nicht ab.** Die Frist gleitet mit; nur eine liegengebliebene endet
  nach `DCH_SITZUNG_TAGE`. Darauf beruht die Wandanzeige, die früher ein Gerätecookie mit einem
  halben Jahr Frist hatte.
- **Die Rechte liegen im Dienst**, nicht in der Anzeige: `apps/api/src/dch_api/auth/rechte.py`.
  Eine ausgeblendete Kachel hält niemanden auf, der die Adresse kennt - und die iOS-App spricht
  ohnehin direkt mit dem Dienst.
- **Eine Sitzung lässt sich einzeln beenden.** Das war mit dem alten Kiosk-Cookie nicht möglich;
  dort hätte man das Geheimnis für alle wechseln müssen.

## Die vier Rollen

| Rolle | darf lesen | darf stellen |
|---|---|---|
| `hausherr` | alles | alles - auch Rechnungen, Verwaltung, Export |
| `bewohner` | alles außer den Akten | im Haus: Räume, Kontakte, Mitteilungen, Alfred |
| `service` | alles außer den Akten | am Gerät: Update, Neustart, Dienste |
| `gast` | alles außer den Akten | nichts |

**Die Akten** sind das, was in die Steuerakte und in die Privatsphäre gehört und dem Hausherrn
bleibt: die Tibber-Rechnungen (Name, Adresse, Marktlokation, Zählernummer, IBAN), die
PV-Abrechnung mit ihren Bemessungsgrundlagen, der Datenexport des gesamten Bestands, das Protokoll
der Haustür (wer wann kam) und die Personenverwaltung selbst.

Die Haustür **öffnet** über diesen Dienst niemand - das macht der Leser im Haus über die Bridge
([TUEROEFFNUNG.md](TUEROEFFNUNG.md)). Hier liegt nur ihr Protokoll, und das ist eine Akte.

Ein neuer Endpunkt, den `rechte.py` nicht kennt, ist für alle Angemeldeten **lesbar** und nur für
den Hausherrn **stellbar**. Das ist die Richtung, in der ein Versehen harmlos bleibt: ein neuer
Bericht wird versehentlich sichtbar, ein neuer Schalter nicht versehentlich bedienbar.

## Der erste Hausherr

Es gibt mit Absicht keinen offenen Weg „ersten Zugang hier anlegen": wer die Adresse zuerst fände,
hätte das Haus. Stattdessen entscheidet, wer die Umgebung des Dienstes setzen kann - dieselbe
Person, die auch an die Datenbank käme:

1. Auf dem **api**-Dienst `DCH_ERSTE_PERSON=<E-Mail>` setzen und neu starten.
2. Ist die Personentabelle leer, legt der Dienst diesen Zugang als `hausherr` an und schreibt den
   Einladungslink **einmal** ins Protokoll, als Warnung, damit er beim Hochfahren auffällt.
3. Den Link auf dem Gerät öffnen, das künftig anmeldet, und dort einen Passkey anlegen. Damit ist
   man angemeldet, und die zehn Wiederherstellungscodes erscheinen - auch nur einmal.

Danach tut die Variable nichts mehr: bei jedem Start prüft sie, ob wirklich noch niemand da ist.
Wer den Link im Protokoll verpasst, lässt sie stehen und startet neu, solange noch niemand
hereingekommen ist; danach stellt der Hausherr unter **System › Zugang und Sicherung** neue Links aus.

### Das Gerät an der Wand

Es bekommt eine eigene Person. Gib ihr einen Namen, dem man ansieht, dass kein Mensch
dahintersteht - „Wandanzeige Flur" - und die Rolle, die sie wirklich braucht; `gast` für eine reine
Anzeige, `bewohner`, wenn am Display auch geschaltet werden soll. Der Passkey liegt dann auf dem
iPad, und das Protokoll nennt diesen Namen.

Das ist ein Zugeständnis und soll als solches dastehen: ein Passkey auf einem Gerät, das im Flur
jeder anfassen kann, ist schwächer als einer im Schlüsselbund eines Menschen. Der Tausch war
bewusst - der Pairing-Link davor war schwächer, weil er unbefristet Vollzugriff vergab und nicht
einzeln widerrufbar war.

## Einladen

Auf **System › Zugang und Sicherung**: E-Mail-Adresse, Name, Rolle. Der Link kommt in jedem Fall zurück und
steht dort zum Kopieren; ist ein Postausgang eingerichtet
(`DCH_SMTP_*` oder `DCH_RESEND_SCHLUESSEL`), geht er zusätzlich per E-Mail hinaus. **Der Versand
ist eine Beigabe, kein Torwächter:** schlägt er fehl, ist die Person trotzdem angelegt.

Ein Link gilt einmal und 72 Stunden (`DCH_ZUGANGSTOKEN_STUNDEN`). Ein neuer entwertet den alten -
zwei gültige Links für dieselbe Person sind einer zu viel.

### Den Postausgang einrichten

Alles davon gehört auf den **api**-Dienst. Zwei Wege, und sie schließen einander aus; ist beides
eingetragen, gilt SMTP:

```bash
# Weg 1: SMTP
DCH_SMTP_HOST=smtp.example.org
DCH_SMTP_PORT=587
DCH_SMTP_BENUTZER=versand@duckcurve.de
DCH_SMTP_PASSWORT=…
DCH_SMTP_SICHERHEIT=starttls        # starttls | ssl | keine
DCH_ABSENDER=haus@duckcurve.de

# Weg 2: HTTPS-Versender, wenn ausgehendes SMTP gesperrt ist
DCH_RESEND_SCHLUESSEL=re_…
DCH_ABSENDER=haus@duckcurve.de
```

**Warum es zwei Wege gibt:** manche Hoster sperren ausgehendes SMTP (Port 587 und 465), weil es
für Spam missbraucht wird. Kommt bei Weg 1 nichts an und steht im Protokoll ein
`einladung nicht verschickt` mit `fehler: OSError`, ist das der wahrscheinliche Grund - dann Weg 2
nehmen, der spricht gewöhnliches HTTPS.

**Was nicht in der Software liegt:** die Absenderadresse muss dem Empfänger-Postfach glaubwürdig
sein. Eine Nachricht von `haus@duckcurve.de` ohne SPF- und DKIM-Einträge in der DNS-Zone von
`duckcurve.de` landet im Spam oder wird abgewiesen - bei Gmail und Outlook regelmäßig. Ein
Transaktionsversender führt durch diese Einträge; bei SMTP über ein vorhandenes Postfach genügt
es meist, dessen eigene Adresse als Absender zu nehmen.

Auf der Seite **System › Zugang und Sicherung** steht, was noch fehlt: ohne Konfiguration sagt sie
„E-Mail-Versand ist nicht eingerichtet" und nennt die Variablen. Und was auch immer beim Versand
schiefgeht - die Person ist angelegt, und der Link steht dort zum Kopieren. Der Versand ist eine
Beigabe, kein Torwächter.

## Das Passwort

Wer keinen Passkey verwenden möchte, vergibt hinter dem Einladungslink ein Passwort und meldet
sich danach mit E-Mail-Adresse und Passwort an.

- **Regeln:** mindestens zwölf Zeichen, sonst keine Vorschrift. Ein Satz ist besser als ein
  kurzes Wort mit Sonderzeichen.
- **Abgelegt** ist nur ein Argon2id-Hash (`apps/api/src/dch_api/auth/passwort.py`).
- **Zehn Fehlversuche** je Adresse sperren die Anmeldung mit Passwort und mit
  Wiederherstellungscode für fünf Minuten. Der Passkey derselben Person geht währenddessen
  weiter.
- **Wechseln** kann die angemeldete Person ihr Passwort, wenn sie das bisherige nennt. Danach
  enden ihre anderen Sitzungen.
- **Beides zugleich** geht: Wer einen Passkey hat, kann ein Passwort dazu vergeben, und
  umgekehrt. Einer der beiden Wege muss bleiben.

Die Schnittstelle dazu: `POST /api/v1/auth/anmeldung/passwort`, `/auth/einladung/passwort`,
`/auth/passwort` und `/auth/passwort/loeschen`.

## Der Rückweg

Vier Stufen, in dieser Reihenfolge - und die ersten beiden sind die, die man vorbereitet haben
muss, bevor man sie braucht:

1. **Ein zweiter Passkey**, am besten auf einem zweiten Gerät. Ein in der Wolke gesicherter
   Passkey (iCloud-Schlüsselbund, Google-Passwortmanager) liegt ohnehin auf mehreren.
2. **Die Wiederherstellungscodes.** Zehn Stück, je einmal gültig, abgelegt nur als Hash. Auf der
   Anmeldeseite unter „Alle Geräte verloren?" mit E-Mail-Adresse und Code anmelden - und dann
   gleich einen neuen Passkey anlegen und neue Codes holen.
3. **Ein neuer Link des Hausherrn.** Er entwertet alle offenen Links und beendet alle Sitzungen
   der Person; danach legt sie einen neuen Passkey an oder vergibt ein neues Passwort. Das ist
   auch der Weg, wenn jemand sein Passwort vergessen hat.

4. **Der Notzugang.** Fällt alles andere zugleich aus, setzt der Betreiber auf dem api-Dienst
   `DCH_NOTZUGANG=<E-Mail>` und startet neu: die Person wird wieder aktiv, wird `hausherr` und
   bekommt einen Einladungslink ins Protokoll. **Danach die Variable wieder entfernen** - solange
   sie steht, entsteht bei jedem Start ein neuer Link, und wer das Protokoll liest, kommt herein;
   der Dienst sagt das bei jedem Start als Warnung.

   `DCH_ERSTE_PERSON` leistet das **nicht**: sie greift nur bei leerer Personentabelle. Wer sich
   aussperrt, hat ja schon einen Zugang - genau daran fehlte es am 23.11.2026, als die RP-ID
   wechselte und der einzige Passkey an die alte gebunden war.

Der Notzugang gehört dem, der die Umgebung des Dienstes setzen kann - und das ist dieselbe Person,
die auch an die Datenbank käme. Auf einem Hausgerät beim Kunden ist das der Betreiber und nicht
der Kunde; darum steht in ADR-0003 die Vollmacht aus der Zentrale.

## Was das Protokoll jetzt sagt

Vorher stand in jeder Zeile ein Gerätename. Jetzt steht bei einer angemeldeten Person
`art: person` mit ihrer Kennung und ihrem Namen, und das Gerät bleibt daneben: „Moritz, am iPad
Flur" ist die vollständige Auskunft. Alte Zeilen behalten `art: geraet` und behaupten nie eine
Person. Der Anzeigename wird **mitgeschrieben**, nicht nachgeschlagen - wer später gelöscht oder
umbenannt wird, verändert das Protokoll nicht ([URHEBER.md](URHEBER.md)).

Und ein Unterschied, der dazugehört: bei einer Person ist die Angabe keine Behauptung mehr. Beim
Gerät bleibt sie eine Zuordnung - wer das API-Token hat, könnte jeden Namen behaupten; er könnte
aber ohnehin alles.

## Einrichten

Auf dem **api**-Dienst (Railway); der web-Dienst braucht davon nichts:

```
DCH_PASSKEY_RP_ID=home.duckcurve.de
DCH_PASSKEY_HERKUENFTE=["https://home.duckcurve.de"]
DCH_ANMELDE_URL=https://home.duckcurve.de
DCH_ERSTE_PERSON=<E-Mail>                 # nur beim allerersten Start
```

Auf dem **web**-Dienst nichts: die Anmeldung ist an, solange `DCH_ANMELDUNG` nicht auf `aus`
steht.

In der Entwicklung:

```
DCH_PASSKEY_RP_ID=localhost
DCH_PASSKEY_HERKUENFTE=["http://localhost:3000"]
```

`localhost` gilt dem Browser als sicherer Kontext, auch ohne https - WebAuthn läuft dort also.
Alle Variablen stehen in [CONFIGURATION.md](../CONFIGURATION.md).

## Geprüft im Browser

Am 23.11.2026 lief der ganze Weg in Chromium mit einem virtuellen Authenticator (Chrome DevTools
Protocol, Nutzerprüfung eingeschaltet) gegen `next dev` und den Dienst mit SQLite. Wiederholbar
mit `tools/rauchprobe-anmeldung.sh` (braucht Playwright mit Chromium):

1. Ohne Cookie führt jede Adresse auf `/anmeldung`, und die Seite sagt, dass noch niemand einen
   Zugang hat.
2. Gerät paaren, erste Person anlegen, Einladungslink erzeugen.
3. Hinter dem Link einen Passkey anlegen: die zehn Wiederherstellungscodes erscheinen, danach ist
   man angemeldet.
4. `/api/session` meldet `art: person` und Rolle `hausherr`.
5. Abmelden, mit Passkey wieder anmelden - und wieder als dieselbe Person.

**Zwei Fehler hat erst diese Probe gefunden,** weil beide aus dem Zusammenspiel mit Next
entstehen und keine Einheitenprüfung sie sieht:

- **Die Wiederherstellungscodes verschwanden, bevor man sie lesen konnte.** Die Server Action
  setzt beim Anlegen ein Cookie; daraufhin rendert Next die Serverkomponente neu, der Link ist
  dann eingelöst, und die Seite wechselte auf „Der Link wurde schon benutzt" - samt dem Zustand,
  in dem die Codes lagen. Sie gehen nur einmal hinaus. Die Seite hält ihren Zweig jetzt stabil
  und lässt die Komponente selbst entscheiden, was sie zeigt.
- **Auf einem gekoppelten Gerät kam niemand zur Anmeldung.** `/anmeldung` leitete weiter, sobald
  *irgendeine* Sitzung bestand - also auch bei einer bloßen Gerätepaarung. Auf dem Wand-iPad und
  auf jedem Rechner, der einmal den Pairing-Link gesehen hatte, war eine Anmeldung als Person
  damit unmöglich. Weitergeleitet wird jetzt nur noch eine angemeldete Person.

## Grenzen und offene Punkte

- **Die RP-ID gehört diesem Haus allein.** Ein Passkey für `home.duckcurve.de` gilt nicht unter
  `duckcurve.de` und umgekehrt - das ist gewollt, seit beide Produkte nebeneinander laufen
  (ADR-0002, Festlegung 1). Kommt einmal eine zentrale Anmeldung, legt jeder dort einen neuen
  Passkey an.
- **Die iOS-App meldet sich noch nicht als Person an.** Sie spricht direkt mit dem Dienst und
  nutzt weiter das Gerätetoken aus dem Schlüsselbund
  (`apps/ios/DuckCurveKit/Sources/DuckCurveKit/Netz/Zugang.swift`). Für Passkeys braucht sie
  `webcredentials:home.duckcurve.de` in den Associated Domains und eine
  `apple-app-site-association` unter `https://home.duckcurve.de/.well-known/`. Seit die RP-ID auf
  dem eigenen Host steht, liegt diese Datei beim **web**-Dienst dieses Repositories - ein Eingriff
  in DuckCurveWebsite ist dafür nicht mehr nötig.
- **Ohne Datenbank gibt es keine Personen.** Im Demo-Modus läuft der Dienst ohne Postgres; die
  Anmeldung ist dann aus, und `/auth/zustand` sagt das.
- **Ein Passkey auf einem verlorenen Gerät bleibt gültig**, bis die Person ihn unter „Mein
  Zugang" löscht. Ein neuer Link des Hausherrn löscht alte Passkeys nicht - er beendet die
  Sitzungen.
- **Ein Protokoll der Anmeldungen** (wer, wann, womit) gibt es nicht. Die Sitzungsliste zeigt
  den laufenden Zustand, nicht die Geschichte.
- **Ein offener Live-Strom hält seine Prüfung vom Verbindungsaufbau.** Wer mitten in einer
  SSE-Verbindung abgeschaltet wird, sieht die Zahlen weiter, bis der Strom abbricht oder der
  Browser neu verbindet (Watchdog nach 15 Sekunden ohne Frame). Jede andere Anfrage ist sofort
  abgewiesen.
- **Die Anmeldung ist nicht gedrosselt**, außer beim abgetippten Wiederherstellungscode (zehn
  Versuche je Adresse in fünf Minuten). Für die Zeremonie mit Passkey braucht es das nicht: dort
  entscheidet eine Signatur, und die lässt sich nicht erraten.

## Im Code

- Tabellen `personen`, `passkeys`, `passkey_schritte`, `person_sitzungen`, `zugangstoken` in
  `apps/api/src/dch_api/infrastructure/db/models.py`, Wanderung
  `20261123_d6a2b8f41e0b_personen_passkeys.py`.
- Zeremonien in `dch_api/auth/passkeys.py` (Bibliothek `webauthn`), Sitzungen und Verwaltung in
  `dch_api/auth/dienst.py`, die Rechtematrix in `dch_api/auth/rechte.py`, der Ausweis in
  `dch_api/auth/ausweis.py`, der Postausgang in `dch_api/post.py`.
- Der Postausgang wird gegen einen **echten kleinen SMTP-Server** geprüft, nicht gegen ein
  nachgebildetes `smtplib`: `apps/api/tests/test_post.py`. Dort steht auch, dass der Endpunkt den
  Versand wirklich auslöst und dass in der Nachricht derselbe Link steht, den die Antwort nennt.
- Endpunkte unter `/api/v1/auth/…` in `dch_api/routers/auth.py`; die Tür in
  `dch_api/dependencies.py`.
- Oberfläche: `apps/web/src/app/anmeldung/`, `apps/web/src/components/zugang/`, Durchreiche in
  `apps/web/src/app/api/dch/[...path]/route.ts`.
- Tests mit einem Software-Authenticator, der wirklich signiert: `apps/api/tests/test_auth.py`;
  die Matrix Zeile für Zeile in `apps/api/tests/test_auth_rechte.py`.
