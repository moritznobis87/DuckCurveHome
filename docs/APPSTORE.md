# Die App ausliefern

Wie aus dem Xcode-Projekt in `apps/ios/` etwas wird, das auf einem Gerät liegt, das nicht am
Kabel hängt. Drei Wege, und der erste ist für dieses Haus meist der richtige.

| Weg | Wofür | Was er kostet |
|---|---|---|
| **Direkt aus Xcode** | Das iPad an der Wand, das eigene Telefon | Nichts. Mit bezahltem Konto hält das Profil ein Jahr statt sieben Tage. |
| **TestFlight** | Mehrere Geräte, Familie, Updates ohne Kabel | Ein Upload je Fassung. Interne Tester bekommen den Build **ohne Prüfung** durch Apple. |
| **App Store** | Öffentlich | Prüfung durch Apple, Datenschutzerklärung, Screenshots, Fragebogen – und ein Zugang, mit dem ein Prüfer die App benutzen kann. Siehe unten. |

Technisch ist der Upload für TestFlight und Store **derselbe**. Es unterscheidet sich nur, was
danach in App Store Connect passiert.

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
   Repository.

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

- **Interne Tester** (bis 100, alles Benutzer des eigenen App-Store-Connect-Zugangs) bekommen
  den Build sofort, ohne Prüfung durch Apple.
- **Externe Tester** (bis 10 000, per Link) brauchen eine Beta-App-Prüfung – schneller und
  milder als die Store-Prüfung, aber eine Prüfung.
- Jeder Build läuft nach **90 Tagen** ab. Danach ein neuer Upload.

Nach Export-Compliance fragt App Store Connect nicht: `ITSAppUsesNonExemptEncryption: false`
steht schon in `project.yml`, und das ist richtig – die App verschlüsselt nichts selbst, sie
benutzt nur HTTPS.

## App Store: das Zugangsproblem

**Diese App wird in der Store-Prüfung abgelehnt, solange ein Prüfer sie nicht benutzen kann.**
Sie spricht mit einem Dienst in einem bestimmten Haus, hinter einem Token, oft im lokalen Netz.
Ein Prüfer hat weder Haus noch Token und sieht 29 leere Seiten – das ist Richtlinie 2.1
(*App Completeness*), und sie wird zuverlässig angewendet.

Zwei Auswege, und beide sind Arbeit, nicht Formulierung:

1. **Demo-Zugang.** Ein öffentlich erreichbarer Dienst mit Beispieldaten (`railway.json` liegt
   im Repository, Railway liefert HTTPS) und ein Token dafür, eingetragen unter *App Review
   Information* ▸ Demo-Account und in den Notizen.
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

`tools/ios-ausliefern.sh` ist **nicht** gelaufen – `xcodebuild` gibt es nur auf einem Mac, und
dort hat es noch niemand ausprobiert. Geprüft sind nur seine Abbruchwege (kein Xcode, fehlende
Team-Kennung, unbekanntes Argument) und die Syntax. Der erste Lauf gehört darum ohne
`--hochladen` gemacht: dann entsteht eine `.ipa` in `apps/ios/build/export/` und es geht nichts
zu Apple, was man nicht zurückholen kann.
