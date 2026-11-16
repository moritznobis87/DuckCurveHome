# Duck Curve Home auf iPhone und iPad

Eine App für beide Geräte, mit zwei Oberflächen: die **Wandanzeige** auf dem iPad im Querformat
und die **Handansicht** auf dem iPhone. Sie teilen den Kern, die Gestaltung und die Bausteine –
nicht das Gerippe. Warum, steht in [`DuckCurveHome/App/Navigation.swift`](DuckCurveHome/App/Navigation.swift).

Alle 29 Seiten des Dashboards sind da, unter denselben Adressen.

## Bauen

```bash
brew install xcodegen
cd apps/ios && xcodegen generate && open DuckCurveHome.xcodeproj
```

Dann in Xcode unter *Signing & Capabilities* das eigene Team wählen und auf ein Gerät laufen
lassen. Das Projekt selbst liegt nicht im Repository – es entsteht aus
[`project.yml`](project.yml), sechzig Zeilen, die man lesen kann. Ein `.xcodeproj` ist ein
Verzeichnis voller Zufallskennungen, in dem ein Diff Zahlenbrei ist.

## Prüfen

```bash
tools/ios-pruefen.sh            # alles, was ohne Xcode geht
tools/ios-pruefen.sh --schnell  # ohne den Prüfstand
```

Das Skript hält die erzeugten Dateien gegen ihre Quellen, baut und testet den Kern (gegen einen
echten HTTP-Dienst) und parst die Oberfläche. Was es **nicht** prüft, sagt es am Ende selbst.

Auf einem Mac zusätzlich:

```bash
xcodegen generate && xcodebuild -scheme DuckCurveHome -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' build
```

## Wie das Projekt geschnitten ist

Die Linie läuft nicht zwischen „Modell" und „Ansicht", sondern zwischen **was sich ohne macOS
prüfen lässt** und was nicht:

| | |
|---|---|
| `DuckCurveKit/` | Ein Swift-Paket ohne SwiftUI. Baut und testet auf Linux, auf einem Mac, in jeder CI. Hier liegen die Modelle, der API-Client, der Leser des Ereignisstroms, die Formate, das Rechnen der Diagramme und die Geometrie des Hausmodells. **211 Tests.** |
| `DuckCurveHome/` | Die Oberfläche. Lässt sich nur auf einem Mac übersetzen – geparst wird sie überall. |
| `pruefstand/` | Ein Dienst zum Draufhalten: echtes HTTP, echter Ereignisstrom, absichtlich mitten im JSON zerhackt. |

Je mehr Last der Kern trägt, desto weniger kann beim ersten Bauen schiefgehen. Darum steht dort
auch, was man woanders in die Ansicht schreiben würde: die Achsengrenzen eines Diagramms, die
Entscheidung, ob eine Zahl dasteht oder ein Bindestrich, und die Wände des Hausmodells.

### Erzeugte Dateien

Zwei Dinge werden aus dem Dashboard übernommen und nicht abgetippt:

```bash
tools/gen-swift.py      # docs/openapi.json → 170 Codable-Strukturen
tools/gen-zeichen.py    # Icon.tsx → 24 Zeichen mit 71 Pfaden
```

Beide verstehen `--pruefen` und melden Abweichungen, ohne zu schreiben. Das Schema ist dasselbe,
aus dem auch `apps/web/src/lib/api/types.ts` entsteht; ein Feld, das in der API umbenannt wird,
fällt beim nächsten Lauf auf.

### Das Hausmodell ist kein 3D

Das Dashboard zeichnet das Haus mit three.js, 1366 Zeilen. Die App braucht dafür kein SceneKit,
und zwei Zeilen der Vorlage sagen warum: die Kamera ist **orthographisch**, und die Lage jedes
Punkts wird mit einer **Kavalierprojektion** gerechnet. Das ist eine Zeichnung mit ausgerechneten
Koordinaten, keine Szene. Also ist `geometrie.ts` in den Kern portiert – Wände aus Räumen,
Türlücken, Versatz, Projektion, mit Tests – und wird mit `Path` gezogen.

Was dabei fehlt, ist ehrlich zu benennen: die Beleuchtung und das additiv überblendete Glimmen
der Glut. Beides ist Stimmung, keine Auskunft.

## Zugang

Die App spricht **direkt mit dem Dienst** und nicht über das BFF des Dashboards. Ein Browser kann
ein Token nicht verwahren, ein Gerät kann es: es liegt im Schlüsselbund, geschützt durch die
Gerätesperre, und verlässt das Gerät nur als `Authorization`-Kopfzeile.

Eingerichtet wird beim ersten Start: Adresse, das Token aus `DCH_API_TOKEN`, ein Name für dieses
Gerät. Geprüft wird mit einer Anfrage, bevor etwas gespeichert wird.

**Zwei Dinge, die man wissen muss.**

Die App schickt die vier Urheber-Kopfzeilen aus
[`urheber.py`](../api/src/dch_api/urheber.py) selbst, die ihr sonst das BFF anhängt. Ohne sie
stünde im Protokoll wieder nur, *dass* jemand etwas gestellt hat. Die Art ist dabei immer
`geraet`: am iPad im Flur kann jeder gestanden haben, und rückwirkend aus einem Gerät einen
Menschen zu machen wäre eine Erfindung.

Die Rolle „Gast" in der App **blendet aus und sperrt nicht.** Im BFF ist die Beschränkung eine
Tür (der Proxy antwortet mit 403), in der App wäre sie nur eine ausgeblendete Schaltfläche – wer
das Token hat, darf am Dienst alles. Für einen echten Gastzugang trägt man als Adresse das
Dashboard ein und als Pfad `/api/dch`; dann gelten dessen Gastregeln.

## Mitteilungen

Der Dienst verschickt Mitteilungen auf zwei Wegen: als **Web Push** an das Dashboard und als
**APNs** an diese App. Eine iOS-App kann Web Push nicht empfangen – das ist Apples Entwurf.

Beide Wege bedienen dieselben Mitteilungen und dieselben Regeln. Ein APNs-Gerät wird als
Abonnement gespeichert wie jedes andere, nur mit einer Adresse der Form `apns://<token>?env=…`;
`PushService` sieht daran, welchen Weg eine Mitteilung nimmt. Kein zweites Schema, keine
Migration, keine zweite Geräteverwaltung.

### Den Signierschlüssel beschaffen

Das ist die **einzige Stelle des Projekts, an der etwas von außen beschafft werden muss, das sich
nicht selbst erzeugen lässt.** Das VAPID-Paar für Web Push legt der Dienst sich selbst an; einen
APNs-Schlüssel nicht.

1. Im Apple-Developer-Konto unter *Certificates, Identifiers & Profiles › Keys* einen Schlüssel
   anlegen und **Apple Push Notifications service (APNs)** ankreuzen.
2. Die `.p8`-Datei herunterladen. **Sie lässt sich nur einmal herunterladen.**
3. Die Schlüsselkennung steht im Dateinamen (`AuthKey_ABC123DEFG.p8` → `ABC123DEFG`), die
   Teamkennung oben rechts im Konto.

Dann beim Dienst eintragen:

```bash
DCH_APNS_KEY_P8="-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----"
DCH_APNS_KEY_ID="ABC123DEFG"
DCH_APNS_TEAM_ID="1234567890"
DCH_APNS_TOPIC="home.duckcurve.app"
```

Fehlt einer der vier Werte, bleibt der Weg zu, Web Push läuft unberührt weiter, und die App sagt
auf ihrer Seite „Mitteilungen", was fehlt. Ist nur ein Teil eingetragen, warnt der Dienst beim
Start – das ist ein Versehen und kein Verzicht.

Die Umgebung reist mit dem Token: ein Token aus Xcode gilt bei Apple an einer anderen Adresse als
eines aus TestFlight. Darum steht sie in der Adresse, und ein Haus kann beide gleichzeitig haben.

## Die Wandanzeige einrichten

Das iPad an der Wand ist der schwierigere Fall: es läuft Wochen am selben Platz, wird nicht
bedient und soll trotzdem stimmen.

- **Der Bildschirm bleibt an.** Die App schaltet den Ruhezustand ab – nur auf dem iPad. Am
  Telefon wäre das eine Unverschämtheit.
- **Nach fünf Minuten wird daraus ein Bild.** Uhr, der Satz des Reglers, drei große Zahlen. Die
  Seite darunter bleibt am Leben und mit ihr die Verbindung; eine Berührung holt die Bedienung
  zurück.
- **Nach zwei Minuten steht wieder heute da.** Wer vorbeigeht, soll nicht das Gestern eines
  anderen sehen. Am Telefon gilt das nicht: das gehört einem.
- **Geführter Zugriff** (*Einstellungen › Bedienungshilfen › Geführter Zugriff*) hält das iPad in
  der App, wenn jemand daran vorbeiwischt.
- Am Strom lassen. Ohne Ladegerät ist auch die beste Anzeige nach zwei Tagen schwarz.

## Was in dieser App anders ist als im Dashboard

Nicht alles ließ sich übernehmen, und nicht alles sollte:

- **Kein Ziehen und Zoomen im Tagesdiagramm.** Swift Charts bringt `dataZoom` nicht mit.
  Nachgebaut ist stattdessen ein Fadenkreuz, das beim Ziehen die Werte einer Stunde zeigt – an
  einem Tagesdiagramm mit 24 Stunden ist Ablesen die häufigere Frage.
- **Das Anlagenschema ist eine Gruppenansicht**, kein Fließbild. Auf 390 Punkten Breite ist ein
  Schema ein Gewirr.
- **Zahlen und Zeiten sind von Hand gerechnet**, nicht mit `NumberFormatter`. ICU unterscheidet
  sich zwischen Linux und iOS, und ein Test, der nur auf dem Prüfrechner gilt, ist keiner.
- **Ein eigener ISO-Leser**, weil `Date.ISO8601FormatStyle` zwei der vier Formen nicht liest, die
  der Dienst liefert.

## Was noch fehlt

Zehn der 62 Endpunkte ruft die App nicht. Fünf davon mit Absicht, fünf sind Lücken:

| | |
|---|---|
| `push/key`, `push/subscribe`, `push/unsubscribe` | Web Push, nur für den Browser. Die App geht über APNs. |
| `demo`, `health` | Werkzeuge, keine Seiten. Die Demo steuert man mit `curl`. |
| `import/tibber-invoice` | Eine Rechnung als PDF hochladen und prüfen. Gelesene Rechnungen zeigt die App; das Hochladen fehlt. Rechnungen kommen laut [`docs/RECHNUNGSPRUEFUNG.md`](../../docs/RECHNUNGSPRUEFUNG.md) ohnehin über den Dienst herein. |
| `config/heat` | Die Annahmen **ändern**. Die App zeigt sie; geändert werden sie im Dashboard. Eine Zahl, die in jede Euro-Zahl eingeht, hinter einem Stepper auf einem Telefon zu haben, wäre leichtfertig. |
| `system/speicher` | Die Speicherwerte einzeln. Dasselbe steht im Anlagenschema. |

## Was nur auf einem Gerät zu prüfen ist

Dieses Verzeichnis ist so geschnitten, dass möglichst viel ohne Mac geprüft werden kann – aber
die Grenze läuft irgendwo, und sie läuft hier:

- **Ob die Oberfläche typprüfend übersetzt.** Der Parser findet Klammern und Kommata, keine
  falschen Typen. Der erste `xcodebuild` wird Fehler finden.
- **Ob sie richtig aussieht.** Abstände, Umbrüche, das Glasmodell, die Diagramme.
- **Ob APNs wirklich ankommt.** Dafür braucht es den Signierschlüssel, ein Gerät und eine echte
  Mitteilung. Der Weg dorthin ist getestet, die letzte Meile nicht.
