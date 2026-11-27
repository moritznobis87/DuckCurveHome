# Die App ausliefern

Wie aus dem Xcode-Projekt in `apps/ios/` etwas wird, das auf einem Gerät liegt, das nicht am
Kabel hängt. Vier Wege:

| Weg | Wofür | Was er kostet |
|---|---|---|
| **Direkt aus Xcode** | Das iPad an der Wand, das eigene Telefon | Nichts. Mit bezahltem Konto hält das Profil ein Jahr statt sieben Tage. |
| **TestFlight** | Eingeladene Tester, Updates ohne Kabel, keine Store-Seite | Ein Upload je Fassung. Der erste Build einer Fassung geht für externe Tester durch eine Beta-Prüfung. |
| **App Store, nicht gelistet** | Eine echte Store-Seite, die nur über ihren Link erreichbar ist | Die volle Prüfung durch Apple und ein Antrag. Siehe unten. |
| **App Store, öffentlich** | Jeder findet und lädt die App | Dieselbe Prüfung, ohne Antrag. |

**Gewählt ist der dritte Weg.** Der Hausherr hat am 27.11.2026 festgelegt: Die App bekommt eine
Store-Seite mit allen Angaben und geht zuerst an eine Handvoll eingeladener Nutzer, aber sie
soll nicht für jeden auffindbar sein, solange sie kein Produkt ist.

Technisch ist der Upload für alle drei Wege über App Store Connect **derselbe**. Es
unterscheidet sich nur, was danach dort passiert.

## Einmalig einzurichten

1. **Team-Kennung ins Projekt.** In `apps/ios/project.yml` steht `DEVELOPMENT_TEAM: ""`. Die
   eigene Kennung steht unter [developer.apple.com/account](https://developer.apple.com/account)
   ▸ Membership details. Einträgen, dann `cd apps/ios && xcodegen generate`, dann das erzeugte
   Projekt mit einchecken – so will es `project.yml` selbst. Wer sie nicht im Repository haben
   will, setzt stattdessen `export DEVELOPMENT_TEAM=…`; `tools/ios-ausliefern.sh` nimmt beides.
2. **App-ID anlegen.** developer.apple.com ▸ Certificates, Identifiers & Profiles ▸
   **Identifiers** ▸ „+" ▸ App IDs ▸ App ▸ `home.duckcurve.app` (so steht sie in `project.yml`).
   Push dort aktivieren, falls die Mitteilungen auf dem Gerät ankommen sollen.
3. **App-Datensatz anlegen.** [appstoreconnect.apple.com](https://appstoreconnect.apple.com) ▸
   Apps ▸ „+" ▸ Neue App: iOS, Primärsprache Deutsch, Bundle-ID auswählen, SKU frei wählbar.
   Der **Store-Name muss weltweit einmalig** sein – „Duck Curve" kann belegt sein. Der Name auf
   dem Gerät (`CFBundleDisplayName`) ist davon unabhängig und bleibt.
4. **Nur für den Weg über die Kommandozeile:** einen API-Schlüssel in App Store Connect ▸ Users
   and Access ▸ Integrations ▸ App Store Connect API ▸ Keys. Die `.p8`-Datei gibt es **einmal**
   zum Herunterladen; sie gehört nach `~/.appstoreconnect/private_keys/` und **nicht** ins
   Repository. `tools/ios-ausliefern.sh` gibt sie an **beide** `xcodebuild`-Läufe weiter, nicht
   nur an den Upload: `-allowProvisioningUpdates` darf ein Verteilprofil anlegen, und auf einem
   Rechner, an dem niemand in Xcode angemeldet ist, kann sich xcodebuild nur damit ausweisen.
5. **PyYAML für das python3, das die Skripte benutzen.** `tools/xcodeproj-pruefen.py` liest
   `project.yml` damit, und das python3 neben einem frisch eingerichteten Xcode hat es nicht:
   `python3 -m pip install --user pyyaml`. Fehlt es, sagt die Prüfung das in einem Satz.

Für eine kostenlose App braucht es keine Bankverbindung und keine Steuerangaben.

## Jeder Upload

```bash
tools/ios-ausliefern.sh --hochzaehlen --hochladen
```

Das Skript hält zuerst das eingecheckte Projekt gegen `project.yml`, zählt dann die Baunummer
hoch, archiviert gegen ein echtes Gerät (Release) und schickt das Ergebnis. Danach die zwei
geänderten Dateien einchecken – damit das Repository sagt, was im Store liegt.

**Der erste Upload gehört trotzdem in Xcode**, nicht in das Skript: Product ▸ Archive, dann im
Organizer *Distribute App* ▸ *App Store Connect*. Der Organizer prüft Icon, Berechtigungen und
Plist und sagt in Worten, was fehlt; `xcodebuild` sagt dasselbe in Fehlernummern.

Die Baunummer steht doppelt (in `project.yml` und in der erzeugten `Info.plist`) und wird darum
nicht von Hand gestellt:

```bash
tools/ios-version.py --hochzaehlen
```

App Store Connect nimmt **jede Baunummer je Fassung genau einmal** an. Der zweite Upload mit
derselben Nummer wird abgewiesen, nachdem er hochgeladen ist – deshalb zählt das Skript vor dem
Archivieren und nicht danach.

## TestFlight

Nach dem Upload dauert die Verarbeitung Minuten bis zu einer Stunde. Dann:

- **Interne Tester** (bis 100) sind Mitglieder des eigenen Entwicklerteams mit einer Rolle in
  App Store Connect. Sie bekommen den Build sofort, ohne Prüfung durch Apple. Für Freunde taugt
  das nicht: jeder bräuchte einen Zugang zum Entwicklerkonto.
- **Externe Tester** (bis 10 000) werden per E-Mail eingeladen oder kommen über einen
  öffentlichen Link. Der erste Build einer Fassung geht dafür durch eine Beta-Prüfung; Apple
  schreibt, spätere Builds derselben Fassung bräuchten sie womöglich nicht. Pflicht sind eine
  Beta-App-Beschreibung und die Angaben für die Prüfung.
- **Der öffentliche Link ist kein geschlossener Kreis.** Apple sagt es selbst: Jeder kann ihn
  weitergeben, und so kommen Tester in die Gruppe, die niemand eingeladen hat. Wer nur bestimmte
  Personen will, lädt per E-Mail ein und legt keinen Link an.
- Jeder Build ist **90 Tage** lang testbar. Danach ein neuer Upload.

Nach Export-Compliance fragt App Store Connect nicht: `ITSAppUsesNonExemptEncryption: false`
steht schon in `project.yml`, und das ist richtig – die App verschlüsselt nichts selbst, sie
benutzt nur HTTPS.

## App Store, nicht gelistet

Apple nennt das *Unlisted App Distribution*. Eine nicht gelistete App hat eine gewöhnliche
Store-Seite und einen gewöhnlichen Link, erscheint aber in keiner Suche, keiner Kategorie,
keiner Bestenliste und keiner Empfehlung. Wer den Link hat, lädt sie; wer ihn nicht hat, findet
sie nicht.

So kommt man dorthin:

1. Die Store-Seite ausfüllen und die Fassung mit einem Build **zur Prüfung einreichen**. In die
   Notizen für die Prüfung gehört der Satz, dass die App für die nicht gelistete Verteilung
   gedacht ist.
2. Den **Antrag** stellen: [developer.apple.com/contact/request/unlisted-app](https://developer.apple.com/contact/request/unlisted-app/).
   Apple verlangt, dass die App dann schon bei der Prüfung liegt oder im Store ist.
3. Nach der Zusage steht die Verteilungsart unter *Preise und Verfügbarkeit* auf „Nicht
   gelistete App" und gilt auch für alle späteren Fassungen.

Vier Dinge, die man vorher wissen muss:

- **Eine Vorabfassung lehnt Apple ab.** Der Antrag wird abgewiesen, wenn die App als Beta oder
  als unfertig auftritt. Sie muss als fertige App eingereicht werden, auch wenn sie zuerst nur
  an wenige geht.
- **Der Link ist kein Schloss.** Apple schreibt, die App sei für jeden verfügbar, der den Link
  hat, und rät zu einer Sperre in der App selbst. Diese App hat sie von Haus aus: ohne die
  Adresse und die Anmeldung eines Hauses zeigt sie nur das Demo-Haus. Wer ein echtes Haus sehen
  darf, entscheidet also, wer dort einen Zugang bekommt, und nicht, wer den Link kennt.
- **Die Freigabe von Hand einstellen.** Unter *Versionsfreigabe* „Diese Version manuell
  freigeben" wählen, damit die App nach bestandener Prüfung nicht von selbst öffentlich wird,
  bevor der Antrag entschieden ist. Das steht nicht auf Apples Seite; es ist die Vorsicht, die
  sich aus der Reihenfolge ergibt.
- **Ob sich die Wahl zurücknehmen lässt, sagt Apples Seite nicht.** Vor dem Schritt zum
  öffentlichen Produkt ist das bei Apple zu erfragen.

Verworfen wurde der Weg über Promo-Codes für eine geprüfte, aber noch nicht freigegebene
Fassung. Apples Hilfe lässt ihn zu, aber im Entwicklerforum häufen sich Berichte, dass sich die
Codes für eine erste Fassung in diesem Zustand nicht einlösen lassen.

Die volle Prüfung gilt für diesen Weg genauso wie für den öffentlichen, und damit auch der
nächste Abschnitt.

## App Store: das Zugangsproblem

**Diese App wird in der Store-Prüfung abgelehnt, solange ein Prüfer sie nicht benutzen kann.**
Sie spricht mit einem Dienst in einem bestimmten Haus, hinter einem Token, oft im lokalen Netz.
Ein Prüfer hat weder Haus noch Token und sieht 29 leere Seiten – das ist Richtlinie 2.1
(*App Completeness*), und sie wird zuverlässig angewendet.

Zwei Auswege, und beide sind Arbeit, nicht Formulierung. Gewählt ist der erste; wie er
eingerichtet wird, steht im nächsten Abschnitt.

1. **Demo-Haus.** Ein öffentlich erreichbarer Dienst mit Beispieldaten (`railway.json` liegt
   im Repository, Railway liefert HTTPS), den die App mit einem Tipp öffnet.
2. **Schau-Modus in der App.** Die Beispieldaten liegen schon im Kern (`Vorschau` in
   DuckCurveKit, laufen in 211 Tests mit). Ein Schalter im Zugangsschirm, der das Beispielhaus
   zeigt, macht die App ohne jeden Dienst vollständig vorzeigbar – und ist auch sonst nützlich:
   wer sie zum ersten Mal öffnet, sieht etwas.

Weiter verlangt App Store Connect, bevor eingereicht werden kann:

- **Screenshots** für iPhone 6,9″ **und** iPad 13″. Die iPad-Bilder im **Querformat** –
  `UISupportedInterfaceOrientations~ipad` erlaubt nichts anderes. Die genauen Pixelmaße nennt
  der Media Manager in App Store Connect.
- **Datenschutzerklärung als URL.** Pflicht, auch für eine App, die nur im eigenen Haus läuft.
- **App-Privacy-Fragebogen.** Hier müssen Mikrofon und Spracherkennung deklariert werden
  (Alfred: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`). Wo das Gerät
  die Erkennung nicht selbst kann, verlässt Audio das Telefon – das ist eine Datenerhebung und
  gehört angegeben.
- Beschreibung, Keywords, Support-URL, Kategorie, Altersfreigabe, Preis.

## Das Demo-Haus für die Prüfung

Der Hausherr hat am 27.11.2026 den ersten der beiden Auswege gewählt und ihn am selben Tag
vereinfacht: Der Prüfer bekommt ein Demo-Haus, und er muss dafür nichts eintragen. Auf dem
Einrichtungsschirm der App steht unter der Anmeldung der Knopf „Demo ansehen". Ein Tipp darauf
verbindet die App mit dem Demo-Haus.

Das Demo-Haus ist der Dienst im Demo-Modus, bei Railway bereitgestellt, **offen und ohne
Token**. Seine Adresse steht fest im Programm (`Zugang.demohaus`):

    https://duckcurvehome-production-7dd0cc79.up.railway.app

Das ist die Adresse, die Railway dem Dienst selbst gegeben hat. Niemand tippt sie, also braucht
sie keine eigene Domain. Der Preis dafür: Wird der Dienst bei Railway gelöscht und neu angelegt,
bekommt er eine andere Adresse, und der Knopf zeigt ins Leere, bis eine neue Fassung der App
ausgeliefert ist. Der Dienst wird darum nur neu ausgerollt und nie neu angelegt.

Die Instanz braucht eine einzige Variable, `DCH_MODE=demo`, und auch die ist nur die Vorgabe.
Keine Datenbank, keine Bridge, kein Tibber, kein zweiter Dienst für das Dashboard: die App
spricht nur mit der API. Gebaut wird aus `apps/api/Dockerfile`, wie `railway.json` es vorgibt.
Sie muss laufen, wann immer Apple prüft, also bei jeder neuen Fassung.

**Die App öffnet das Demo-Haus mit vollem Umfang.** Der Hausherr hat das am 27.11.2026 so
entschieden: Der Prüfer soll alles sehen, also auch die Stellgriffe und die Seiten, die sonst
dem Hausherrn bleiben. Zuerst öffnete die App das Demo-Haus als Gast.

**Offen heißt offen, auch zum Stellen.** Ohne `DCH_API_TOKEN` lässt der Dienst jede Anfrage
herein und behandelt sie wie den Betreiber (`dependencies.require_zugang`). Wer im Demo-Haus
etwas verstellt, in der App oder von Hand über die Schnittstelle, verstellt es für alle, die
gerade zusehen. Verloren geht dabei nichts, denn das Haus ist simuliert und beginnt bei jedem
Neustart von vorn. Es kann aber vorkommen, dass ein Prüfer ein Haus sieht, das ein anderer
gerade verstellt hat.

Was die Seiten des Hausherrn im Demo-Haus zeigen, nachgesehen am 27.11.2026 an der Instanz:
Die PV-Abrechnung hat Werte. Das Protokoll der Haustür und die Rechnungen sind leer und sagen
das in einem Satz. Die Personenverwaltung antwortet mit 503, weil der Demo-Modus keine Personen
kennt; die App hat diese Seite nicht.

Nachgemessen am 27.11.2026:

| Anfrage | Wo | Antwort |
|---|---|---|
| `/health` | Railway | 200, Modus `demo` |
| Live-Zustand, Fahrplan und Tagesbilanz ohne Token, mit den Kopfzeilen der App als Gast | Railway | 200 |
| Eine Solltemperatur stellen, ohne Token | lokale Kopie ohne Token | 200, der Raum steht danach auf dem neuen Wert |
| Anmeldung mit Passwort | lokale Kopie | 503, „Die Anmeldung braucht eine Datenbank; dieser Dienst läuft im Demo-Modus." |

Geschrieben wurde nur gegen die lokale Kopie, damit die Messung das öffentliche Demo-Haus nicht
selbst verstellt. Nicht nachgemessen ist der Knopf am Gerät: ob er richtig aussieht und ob die
App danach das Demo-Haus zeigt, lässt sich nur am iPhone und am iPad sehen.

In den Angaben für die Prüfung steht damit, dass keine Anmeldung nötig ist, und in den Notizen
ein Satz: auf dem ersten Schirm „Demo ansehen" tippen.

## Push

In `project.yml` ist die Berechtigung `aps-environment` auskommentiert, mit Begründung: ein
kostenloses Konto darf sie nicht führen, und Xcode bricht dann die Signierung ab. Mit dem
bezahlten Konto können die vier Zeilen zurück; danach `xcodegen generate` und mit einchecken.

Für TestFlight- und Store-Builds muss dabei die **Produktionsfassung** der Berechtigung im
Archiv landen. Mit automatischer Signierung macht Xcode das beim Archivieren selbst. Wenn
Pushes aus einem TestFlight-Build nicht ankommen, aus einem Gerätebuild aber schon, ist das die
erste Stelle zum Nachsehen: im Organizer das Archiv auswählen, *Show in Finder*, Paketinhalt,
und in der `.app` die Berechtigungen ansehen.

## Was hier nicht nachgemessen ist

`tools/ios-version.py` ist geprüft: die Baunummer wandert durch beide Dateien, die `Info.plist`
bleibt byte-identisch zu dem, was XcodeGen schreibt, und `tools/xcodeproj-pruefen.py` bleibt
grün. Das lief auf Linux.

**Am 27.11.2026 ist es auf einem Mac gelaufen, ohne `--hochladen`**, und zwar durch:
`ARCHIVE SUCCEEDED`, dann `EXPORT SUCCEEDED`, am Ende eine `DuckCurveHome.ipa` mit 10,7 MiB in
`apps/ios/build/export/`. Gebaut gegen das iPhoneOS-27.2-SDK, `arm64-apple-ios17.0`, Swift 6,
Fassung 1.0 (Bau 1), automatische Signierung mit einem bezahlten Team. Zwei Dinge sind dabei
aufgefallen und behoben: dem `python3` der Shell fehlte PyYAML (jetzt sagt die Wache das in
einem Satz), und `xcodebuild` schrieb ein paar tausend Zeilen, in denen das Ergebnis unterging
(jetzt `-quiet`).

**Nicht gelaufen ist der Upload.** `--hochladen` mit echten API-Schlüsseln hat nie jemand
ausprobiert; geprüft ist davon nur, *was* aufgerufen würde – mit einem vorgeschobenen
`xcodebuild`, das seine Argumente ausgibt: ohne Schlüssel, mit Schlüsseln (die dann in beiden
Aufrufen stehen), `--hochladen` ohne Schlüssel (bricht ab, **bevor** archiviert wird),
`--hochladen` mit Schlüsseln (`destination: upload`), und ein Schlüsselpfad, der ins Leere
zeigt.

Ebenfalls offen und nicht durch ein Skript zu prüfen: ob App Store Connect den Build annimmt,
und alles, was danach dort von Hand ausgefüllt wird.
