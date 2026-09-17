# Haustür: Gesichtsscan öffnet die Falle

Der Reader erkennt ein Gesicht, die Tür geht auf. Dazwischen liegt möglichst wenig.

```
UniFi Access G2 Reader Pro
        │  (Gesichtsscan)
UniFi-Konsole
        │  wss://<konsole>:12445/api/v1/developer/devices/notifications
DCH-Bridge im Haus
        │  http://<schloss>:8080/lockAction?...&action=3
Nuki Smart Lock Pro
```

Alles im Heimnetz. Weder die DCH-Cloud noch Home Assistant noch die Nuki-Cloud stehen in diesem
Weg. Das ist der Zweck der Sache: eine Tür, die nur aufgeht, wenn drei Dienste und zwei
Internetstrecken gleichzeitig mitspielen, geht irgendwann nicht auf.

`action=3` heißt bei Nuki **unlatch** und zieht die Falle. Die Tür geht damit wirklich auf, statt
dass nur der Riegel zurückgeht. Ob das mechanisch möglich ist, entscheidet das Schloss in der Tür.

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

1. Zugangsdaten setzen. Der Access-Token entsteht in der Access-Oberfläche unter Einstellungen →
   Allgemein → API-Token, der Nuki-Token in der Nuki-App beim Einschalten der HTTP-API unter
   „Geräte verwalten" (6 bis 20 Zeichen).

   ```
   DCH_BRIDGE_UNIFI_HOST=192.168.x.x
   DCH_BRIDGE_UNIFI_TOKEN=…
   DCH_BRIDGE_NUKI_HOST=192.168.x.x
   DCH_BRIDGE_NUKI_TOKEN=…
   ```

2. Einmal vor die Tür stellen und das Gesicht scannen lassen. Im Protokoll der Bridge steht dann

   ```
   access event door=Haustür actor=Moritz method=FACE granted=True open_door=False
                reason=Türöffnung ist nicht freigegeben (Beobachtungsbetrieb).
   ```

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
