# Urheber: wer etwas verändert hat

Im Protokoll stand bisher, *dass* jemand den Sollwert gestellt hat, und seit dem Raumprotokoll
auch, *dass* es über dieses Werkzeug ging. Wer es war, stand nirgends - obwohl die Sitzung es
längst weiß: Beim Paaren bekommt jedes Gerät einen Namen, und der steht signiert im Cookie.

```
/pair?token=<DCH_KIOSK_TOKEN>&name=iPad-Flur
```

Dieser Name reist jetzt bis in die Datenbank.

## Vier Felder, nicht ein Name

Ein Urheber ist zusammengesetzt, damit ein späteres Benutzersystem nichts umschreiben muss:

| Feld | heute | mit Benutzersystem |
| --- | --- | --- |
| `art` | `geraet` | `person` |
| `id` | `ipad-flur` | `u_17` |
| `name` | `iPad Flur` | `Moritz` |
| `geraet` | `iPad Flur` | `iPad Flur` |
| `rolle` | `owner` | `owner` |

Das Gerät bleibt also stehen, wenn die Person dazukommt. „Moritz, am iPad im Flur" ist die
vollständige Auskunft, und sie entsteht ohne Umbau der Ablage.

**Alte Zeilen bleiben, was sie sind.** Sie behalten `art: geraet` und behaupten nie, eine Person
zu kennen. Rückwirkend aus einem Gerät einen Menschen zu machen wäre eine Erfindung, auch wenn
meistens derselbe davor saß.

**Der Anzeigename wird mitgeschrieben, nicht nachgeschlagen.** Wer ein Gerät umbenennt oder einen
Benutzer löscht, verändert damit kein Protokoll.

## Der Weg durch die Schichten

```
Browser ──Cookie──▶ BFF-Proxy ──x-dch-urheber-*──▶ Dienst ──ContextVar──▶ add_event / save_config
```

1. **`apps/web/src/app/api/dch/[...path]/route.ts`** liest die Sitzung und setzt die Kopfzeilen
   `x-dch-urheber-art`, `-name`, `-geraet`, `-rolle`.
2. **`apps/api/src/dch_api/main.py`** legt daraus je Anfrage eine Kontextvariable an.
3. **`apps/api/src/dch_api/urheber.py`** hält das Wertobjekt und die Variable. Das Modul liegt
   oben neben `errors.py` und `settings.py`, nicht in `application/`: Infrastruktur darf es
   benutzen, ohne die Schichtung zu verletzen (`lint-imports` prüft das).
4. **`repositories.add_event`** hängt den Urheber von selbst an jedes Ereignis, das aus einer
   Anfrage entsteht. **`save_config`** nimmt ihn als `created_by`; vorher stand dort fest
   verdrahtet `owner`, eine Angabe, die niemanden bezeichnete.

Im Ereignis steht er als flache Punktschlüssel, wie `raum.1.name`:

```json
{"room": 3, "to": 21.5, "urheber.art": "geraet", "urheber.id": "ipad-flur",
 "urheber.name": "iPad Flur", "urheber.geraet": "iPad Flur", "urheber.rolle": "owner"}
```

Flach und als Zeichenkette, damit es sich in der Datenbank durchsuchen lässt und auch über die
Brücke trägt, deren Kontext nur Zeichenketten kennt.

## Was nicht mitgeschrieben wird, und warum

**Außerhalb einer Anfrage steht kein Urheber am Ereignis.** Takt, Start und Brücke schreiben ohne
Angabe. Ein „System" an jeder der zehntausend Brückenmeldungen wäre Rauschen und kein Hinweis.

**Die Automatik unterschreibt selbst.** `_room_shift_one` setzt den Urheber ausdrücklich auf
`Automatik`, auch wenn ein Mensch den Durchlauf ausgelöst hat: Wer die Automatik einschaltet,
stößt sofort einen Takt an, und ohne diese Zeile stünde sein Name unter einer Sollwertänderung,
deren Wert nicht er gewählt hat.

**Leer heißt unbekannt, nicht „niemand".** Änderungen, die nicht über dieses Werkzeug liefen,
haben keinen Urheber - siehe `application/room_log.py` zur Unterscheidung von „von außen".

## Wie weit die Angabe trägt

Der Dienst glaubt den Kopfzeilen, weil hinter derselben Tür das API-Token steht. **Wer das Token
hat, kann jeden Urheber behaupten** - er kann aber ohnehin alles. Es ist also eine *Zuordnung*,
keine Beweisführung; für Letzteres müsste der Browser selbst signieren. Für die Frage „wer hat
die Heizung hochgedreht" reicht es, und das steht hier, damit es niemand später für mehr hält.

## Wenn das Benutzersystem kommt

Zu tun ist dann genau eine Stelle, der Rest trägt sich selbst:

1. Die Sitzung um eine Benutzerkennung erweitern (`issueSession` in `apps/web/src/lib/session.ts`).
2. Im BFF-Proxy `x-dch-urheber-art: person`, `-id: <Benutzerkennung>`, `-name: <Anzeigename>`
   setzen und den Gerätenamen weiter als `-geraet` mitschicken.

Dienst, Ablage und Anzeige bleiben unverändert: Sie kennen `person` bereits, und `Urheber.text()`
setzt daraus „Moritz, am iPad Flur" zusammen. Eine Datenbankänderung ist nicht nötig, weil der
Urheber im JSON-Kontext steht.

**Nicht zu tun:** alte Zeilen nachträglich einer Person zuordnen. Sie sagen „iPad Flur", und das
ist die Wahrheit, die damals bekannt war.
