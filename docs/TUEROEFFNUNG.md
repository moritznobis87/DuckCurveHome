# Haustür: Gesichtsscan öffnet die Falle

Der Reader erkennt ein Gesicht, die Tür geht auf. Dazwischen liegt möglichst wenig.

```
UniFi Access G2 Reader Pro
        │  (Gesichtsscan)
UniFi-Konsole
        │  wss://<konsole>:12445/api/v1/developer/devices/notifications
DCH-Bridge im Haus
        │  lock.open auf der Matter-Entität
Home Assistant  →  HomePod (Thread-Border-Router)  →  Nuki Smart Lock Pro
```

Alles im Heimnetz, ohne Internetstrecke. Das ist der Zweck: eine Tür, die nur aufgeht, wenn drei
Dienste und zwei Internetstrecken gleichzeitig mitspielen, geht irgendwann nicht auf.

`lock.open` zieht die **Falle** und öffnet die Tür wirklich; `lock.unlock` dreht nur den Riegel
zurück. Ob die Matter-Anbindung des Schlosses das Öffnen hergibt, hängt von Gerät, Firmware und
HA-Version ab. Deshalb steht der Dienstname in der Konfiguration (`door_service`) und nicht im
Quelltext: das probiert man in zehn Sekunden aus und schlägt es nicht zuverlässig nach.

## Warum nicht direkt zum Schloss

Zwei Wege, die naheliegen, führen hier nicht hin.

**Eine lokale HTTP-API am Schloss gibt es nicht.** Sie existiert nur an der Nuki-Bridge, dem
Steckdosengerät. Nuki sagt zum Smart Lock Pro der 4. Generation ausdrücklich: „the Smart Lock Pro
(4th Generation) does not include the HTTP API".

**MQTT gibt es, kostet aber die Batterie.** Es setzt das WLAN des Schlosses voraus, und nach Nukis
eigener Rangfolge ist WLAN die teuerste Verbindungsart - Bluetooth am sparsamsten, Thread wenig
darüber, WLAN deutlich dahinter. Ein Schloss, das über Thread am HomePod hängt, hat sein WLAN aus
und hält dafür rund ein halbes Jahr. Das gibt man nicht für einen Türöffner auf.

Bleibt der Weg über Matter, den es ohnehin schon gibt: Home Assistant tritt als **zweiter
Verwalter** derselben Matter-Fabric bei. Apple Home behält das Schloss, das WLAN bleibt aus, der
HomePod routet. In der Home-App teilt man das Zubehör, in HA fügt die Matter-Integration es mit
dem Kopplungscode hinzu.

## Der Ausweg, falls diese Strecke nicht trägt

Sie hat einen Preis: Home Assistant und der Border Router stehen jetzt in der Kette. Ob das trägt,
ist eine Tatsachenfrage, und sie wird gemessen. Die Bridge fragt den Zustand der Schloss-Entität
im Minutentakt ab und schreibt ihn als Messreihe `door_lock_online`; auf `/daten` erscheint sie in
derselben Verfügbarkeitskarte wie der Stromzähler. Nach ein paar Wochen steht dort, ob die Strecke
aussetzt und wann.

Setzt sie aus, wandert der Türweg auf eine **Nuki-Bridge**: das Steckdosengerät spricht Bluetooth
mit dem Schloss und bietet die lokale HTTP-API. Damit fallen Home Assistant **und** der HomePod aus
dem Türweg heraus, das WLAN bleibt trotzdem aus, und Apple Home läuft unberührt weiter. Der Wechsel
ist dann eine Einstellung (`door_opener: nuki_bridge`) und keine Änderung am Programm - der Öffner
ist deshalb austauschbar gebaut.

## Die Cloud hat keinen Weg zur Tür

Es gibt in DCH keinen Endpunkt, keine Schaltfläche und keinen Befehl, der beim Türdienst ankommt.
Der einzige Auslöser ist ein Zutrittsereignis der Konsole, geprüft gegen eine Erlaubnisliste, die
in der Konfiguration der Bridge steht. Ein Fehler in der Cloud kann diese Tür nicht öffnen, weil es
dafür keinen Pfad gibt - nicht, weil wir ihn gerade versperrt haben.

Die Prüfung selbst liegt in `hems_core.control.door_access`: eine reine Funktion, ohne Netz, ohne
Geräte, mit Tests für jede einzelne Bedingung. Sie lässt durch, was **ausdrücklich** erlaubt ist,
und lehnt alles andere ab. Eine leere Liste heißt niemand, nicht alle.

Fünf Gründe abzulehnen, jeder einzeln im Protokoll sichtbar:

* die Konsole hat den Zutritt selbst abgelehnt,
* das Ereignis ist älter als 30 Sekunden (nach einem Verbindungsabbruch liefert die Konsole
  zurückliegende Einträge nach; eine Tür, die aufgeht, weil vor zwanzig Minuten jemand davorstand,
  ist ein Fehler),
* die Tür steht nicht in der Liste,
* die Person steht nicht in der Liste,
* das Verfahren steht nicht in der Liste (ein PIN ist kein Gesichtsscan),
* dieselbe Person hat innerhalb der letzten acht Sekunden geöffnet.

Die Wiederholsperre greift erst nach einer **tatsächlich ausgeführten** Öffnung. Wer vor der Tür
steht und einen Fehlschlag erlebt, darf sofort erneut - die Sperre soll doppelte Zustellungen
abfangen, nicht Menschen.

## Inbetriebnahme

Der Dienst startet im **Beobachtungsbetrieb** und rührt das Schloss nicht an. Das ist keine
Vorsichtsgeste: der Wert, den die Konsole für einen Gesichtsscan in `authentication_type` schreibt,
ist nirgends dokumentiert, und die Anzeigenamen von Tür und Person stehen so, wie sie jemand
einmal eingetippt hat. Beides liest man ab, statt es zu raten.

1. Zugangsdaten und Ziel setzen. Der Access-Token entsteht in der Access-Oberfläche unter
   Einstellungen → Allgemein → API-Token. Die Entität ist die des Schlosses in Home Assistant.
   Vorher einmal ausprobieren, ob `lock.open` darauf die Falle zieht - wenn nicht, gehört
   `lock.unlock` in `door_service`, und die Tür geht dann nur auf Riegel.

   ```
   DCH_BRIDGE_UNIFI_HOST=192.168.x.x
   DCH_BRIDGE_UNIFI_TOKEN=…
   DCH_BRIDGE_DOOR_ENTITY=lock.haupteingang_nuki
   DCH_BRIDGE_DOOR_SERVICE=lock.open
   ```

2. Einmal vor die Tür stellen und das Gesicht scannen lassen. Im Protokoll der Bridge steht dann

   ```
   access event door=Haustür actor=Moritz method=FACE granted=True open_door=False
                reason=Türöffnung ist nicht freigegeben (Beobachtungsbetrieb).
   ```

   Stehen dort **drei leere Felder**, hat die Konsole eine andere Bauform geschickt als erwartet.
   Das ist kein abgelehnter Zutritt, auch wenn es beim ersten Versuch genau so im Protokoll stand.
   Die Bridge schreibt in diesem Fall eine zweite Zeile `access event unleserlich` mit dem Rahmen
   im Rohzustand (gekürzt auf 2000 Zeichen), und daraus werden die Feldnamen abgelesen. Der
   Rohrahmen enthält Namen und Kennungen des Hauses; er gehört nicht weitergereicht, ohne ihn
   vorher anzusehen.

   **So sieht der Rahmen an dieser Anlage wirklich aus** (UniFi Access, Herbst 2026, an einem
   Gesichtsscan abgelesen). Die Nutzdaten liegen eine Ebene tiefer als die Beschreibung der
   Schnittstelle vermuten lässt, nämlich unter `data._source`:

   ```
   data._source.actor.display_name              → die Person
   data._source.authentication.credential_provider → das Verfahren, beim Gesicht „FACE"
   data._source.target[] mit type == "door"      → die Tür
   data._source.event.result                     → „ACCESS" bei Erfolg
   data._source.event.display_message            → „Access Granted (Face)"
   data._source.event.published                  → Zeitpunkt in Millisekunden
   ```

   Zwei Dinge daran sind leicht zu übersehen. In `target` stehen auch Hub, Reader, Etage und
   Gebäude, alle mit Anzeigenamen; die Tür ist allein der Eintrag vom Typ `door`. Und das
   Ergebnisfeld trägt bei Erfolg nur das Wort `ACCESS`; das Wort „Granted" steht daneben in
   `display_message`. Wer nur auf `result` nach „granted" sucht, hält jede geglückte Öffnung für
   eine Ablehnung. Eine Ablehnung schlägt im Übrigen jede Zusage: steht irgendwo `denied`,
   `blocked`, `rejected`, `failed`, `abgelehnt` oder `verweigert`, wird nicht geöffnet.

   Flache Rahmen (`result` und `authentication_type` direkt im Rumpf) werden weiterhin gelesen.

3. Die drei Werte in die Erlaubnisliste übernehmen und freigeben:

   ```
   DCH_BRIDGE_DOOR_DOORS=Haustür
   DCH_BRIDGE_DOOR_ACTORS=Moritz
   DCH_BRIDGE_DOOR_METHODS=FACE
   DCH_BRIDGE_DOOR_ENABLED=true
   ```

Groß- und Kleinschreibung und Leerzeichen spielen keine Rolle. Mehrere Werte werden mit Komma
getrennt.

## Was bleibt, wenn die Bridge steht

Dann geht die Tür über diesen Weg nicht auf. Der Schlüssel und die Nuki-App bleiben der
Rückfallweg, und der Reader sollte weiterhin auch ohne uns funktionieren. Eine Automatisierung, die
zur einzigen Art wird, ins Haus zu kommen, ist ein Fehler im Entwurf und nicht im Code.

## Zugangsdaten

Beide Token gehören in die Umgebung der Bridge. Sie stehen nicht im Repository und in keiner
Nachricht. Wer sie hat, kann die Haustür öffnen.
