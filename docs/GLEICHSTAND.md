# Gleichstand von Dashboard und App: offene Befunde

Nach `CLAUDE.md` zeigen Dashboard (`apps/web`) und App (`apps/ios`) dieselben Inhalte, und ein
Unterschied ist ein Fehler. Hier steht, was gefunden und noch nicht behoben ist, mit Fundstelle.
Ein Eintrag verschwindet, sobald beide dasselbe zeigen.

## Texte, die nur das Dashboard hat (gefunden am 24.11.2026)

Beim Umformulieren der Texte mit angehängtem Gedankenstrich hatte jede der folgenden Stellen im
Dashboard kein Gegenstück in der App. Gesucht wurde in `apps/ios` nach einem Kernwort des
Satzes; „fehlt“ heißt, dass das Wort dort in keiner Zeichenkette vorkommt.

| Seite | Text im Dashboard | Fundstelle | Stand in der App |
|---|---|---|---|
| Regelkreis | Die drei Erklärabsätze „Der Regler wird gerechnet, nicht eingestellt“, „Woher die Zahlen kommen“ und „Was die Reserven sagen“ | `components/regelkreis/Regelkreis.tsx`, Abschnitt unter den Kreisen | fehlt; `Regelkreisbild.swift` trägt eine kürzere eigene Fassung |
| Regelkreis | Der Satz zu „Noch keine Übernahme“ mit den drei Bedingungen der Übernahme | `Regelkreis.tsx` | fehlt |
| Regelkreis | Die Bildunterschrift zum Verlauf eines Parameters („Dünn: die laufende Schätzung …“) | `components/regelkreis/Anzeigen.tsx` | fehlt |
| Regelkreis | Die Stichwortzeile über der Parametertabelle mit dem Hinweis auf den Klick | `components/regelkreis/Blatt.tsx` | fehlt |
| Räume, Protokoll | „Keine Einträge. Der Sollwert dieses Raums stand die ganze Zeit still. …“ | `components/rooms/Protokoll.tsx` | fehlt |
| Mitteilungen | Die Fehlermeldung, wenn der Browser kein Abonnement anlegen kann | `components/settings/Mitteilungen.tsx` | bauartbedingt anders: die App meldet sich bei Apple an, nicht bei einem Push-Dienst des Browsers |
| Hausgerät | „Gerade keine Verbindung. Vielleicht startet die API neu; die Seite versucht es weiter.“ | `components/geraet/Geraet.tsx` | fehlt |
| Alfred | Der Hinweis in der Rückfrage, dass die geprüften Felder gezeigt werden und nicht der Text der Antwort | `components/alfred/Alfred.tsx` | fehlt |
| Berichte | „Nicht angemeldet. Bitte das Gerät koppeln.“ | `components/reports/useReport.ts`, `YearMap.tsx` | fehlt als Wortlaut; die App erkennt den abgelehnten Zugang über `ApiFehler.istAnmeldung`, was sie dazu schreibt, ist noch nicht verglichen |
| Zugang und Sicherung | Personen, Einladungslink, Passkeys und Ersatzcodes | `components/zugang/Personen.tsx`, `MeinZugang.tsx`, `app/system/zugang/page.tsx` | fehlt; die App beschreibt stattdessen ihr Token im Schlüsselbund (`Zugangsworte.swift`) |
| Anmeldung | Die Seiten zum Anlegen und Benutzen eines Passkeys | `app/anmeldung/` | bauartbedingt nur im Browser |

Zwei Stellen waren im Wortlaut verschieden und sind mit dieser Änderung angeglichen: die Zeile
der nicht stetigen Kreise („hybrid und ganzzahlig, ohne Frequenzkennlinie“) und der Satz zum
veralteten Bericht des Hausgeräts.

## Form, die sich unterscheidet

| Seite | Dashboard | App | Fundstelle |
|---|---|---|---|
| Regelkreis | Blockschaltbild mit vier Ebenen, darunter die Kreise | Liste der Kreise ohne Schaltbild | `components/regelkreis/Karte.tsx`, `RegelkreisSeite.swift` |

Ob die App das Schaltbild bekommt oder das Dashboard die Liste, entscheidet der Hausherr; die
Frage ist ihm gestellt.

## Was als Nächstes dran ist

Die Zeilen mit „fehlt“ sind echte Lücken und werden Seite für Seite geschlossen, zusammen mit
dem einheitlichen Seitenaufbau. Die Zeilen mit „bauartbedingt“ brauchen eine Entscheidung, ob
die Regel dort eine Ausnahme kennt: Anmeldung über Passkey gibt es nur im Browser, das Token im
Schlüsselbund nur in der App.
