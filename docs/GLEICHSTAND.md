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
| Regelkreis | Die Karte „Die Glieder dieser Strecke“: der Katalog der Übertragungsglieder mit Kennbild, Kurzzeichen und Übertragungsfunktion | `components/regelkreis/Regelkreis.tsx` | fehlt; die App zeigt das Kennbild nur im Kästchen und im Blatt des Blocks |
| Regelkreis | Der Satz zu „Noch keine Übernahme“ mit den drei Bedingungen der Übernahme | `Regelkreis.tsx` | fehlt |
| Regelkreis | Die Bildunterschrift zum Verlauf eines Parameters („Dünn: die laufende Schätzung …“) | `components/regelkreis/Anzeigen.tsx` | fehlt |
| Regelkreis | Die Stichwortzeile über der Parametertabelle mit dem Hinweis auf den Klick | `components/regelkreis/Blatt.tsx` | fehlt |
| Regelkreis | Die drei Leuchten im Kopf der Seite („Arbeitspunkt gemessen“, die Zahl der übersteuerten Parameter, „Reserven in Ordnung“ oder „Reserve zu klein“) | `Regelkreis.tsx` | fehlt; gefunden am 24.11.2026 beim Umstellen der Zustandsfarbe |
| Mitteilungen | Die Fehlermeldung, wenn der Browser kein Abonnement anlegen kann | `components/settings/Mitteilungen.tsx` | bauartbedingt anders: die App meldet sich bei Apple an, nicht bei einem Push-Dienst des Browsers |
| Berichte | „Nicht angemeldet. Bitte das Gerät koppeln.“ | `components/reports/useReport.ts`, `YearMap.tsx` | bauartbedingt anders: die App schreibt „Das Token stimmt nicht mehr. Unter „Zugang“ neu einrichten.“ (`ApiFehler.rat`), weil sie über ein Token im Schlüsselbund angemeldet ist und nicht gekoppelt wird |
| Zugang und Sicherung | Personen, Einladungslink, Passkeys und Ersatzcodes | `components/zugang/Personen.tsx`, `MeinZugang.tsx`, `app/system/zugang/page.tsx` | fehlt; die App beschreibt stattdessen ihr Token im Schlüsselbund (`Zugangsworte.swift`) |
| Anmeldung | Die Seiten zum Anlegen und Benutzen eines Passkeys | `app/anmeldung/` | bauartbedingt nur im Browser |

Zwei Stellen waren im Wortlaut verschieden und sind mit dieser Änderung angeglichen: die Zeile
der nicht stetigen Kreise („hybrid und ganzzahlig, ohne Frequenzkennlinie“) und der Satz zum
veralteten Bericht des Hausgeräts.

Behoben am 24.11.2026, nach der ersten Fassung dieser Liste:

- **Hausgerät:** Antwortet der Dienst nicht, während ein Bericht dasteht, sagt die App jetzt
  denselben Satz wie das Dashboard („Gerade keine Verbindung. …“) und versucht es im kurzen
  Takt weiter. Ihre allgemeine Störungszeile steht nur noch da, wenn es gar keinen Bericht gibt.
- **Räume, Protokoll:** Der Text des leeren Protokolls lautete in der App anders als im
  Dashboard. Jetzt steht in beiden der Wortlaut des Dashboards.
- **Alfred:** Der „Hinweis in der Rückfrage“ stand in der ersten Fassung dieser Liste zu
  Unrecht. Er ist im Dashboard ein Kommentar im Code und kein Text der Oberfläche.

## Form, die sich unterscheidet

| Seite | Dashboard | App | Fundstelle |
|---|---|---|---|
| Regelkreis | Blockschaltbild mit vier Ebenen, darunter die Kreise | Liste der Kreise ohne Schaltbild | `components/regelkreis/Karte.tsx`, `RegelkreisSeite.swift` |

**Entschieden am 24.11.2026:** überall das Blockschaltbild, keine Liste. Die App zeigt seitdem
das Schaltbild des Dashboards (`Regelkreiskarte.swift`). Die Geometrie steht einmal in
`docs/regelkreis-schaltbild.json`; das Dashboard wird mit `layout.test.ts` dagegen gehalten, die
App bekommt `Schaltbilddaten.swift` daraus erzeugt (`tools/gen-schaltbild.py`). Was im Kästchen
steht und wie eine Leitung läuft, rechnet in der App derselbe Code wie im Dashboard, übersetzt
und mit Tests festgehalten (`Schaltbildzeichnung.swift`). Die fünf Absätze der Methode stehen in
der App jetzt im Wortlaut des Dashboards.

Zwei Unterschiede bleiben in der Zeichnung und sind bauartbedingt: Die Formel im Kästchen steht
im Browser kursiv und in der App gerade, weil die Schrift der App keinen kursiven Schnitt hat.
Der gewählte Block hat im Browser einen Lichthof, in der App nur den bernsteinfarbenen Rand.

Das Blatt des gewählten Blocks ist in der App anders aufgebaut als im Dashboard (`Blatt.tsx`
gegen `Blockansicht`); der Vergleich Feld für Feld steht noch aus.

## Anmeldung

**Entschieden am 24.11.2026:** In der App gilt dieselbe Anmeldelogik wie im Browser, und in
beiden gibt es zwei Wege: Passkey oder E-Mail-Adresse und Passwort (ADR-0002, Nachtrag vom
24.11.2026).

Gebaut ist der Dienst (`dch_api/auth/passwort.py`, vier Endpunkte unter `/auth`). Offen sind die
Oberflächen, in dieser Reihenfolge:

1. Dashboard und App: die Anmeldung mit E-Mail-Adresse und Passwort, die Wahl zwischen Passkey
   und Passwort hinter dem Einladungslink, und das Vergeben, Wechseln und Entfernen des
   Passworts unter „Zugang und Sicherung“.
2. App: die Anmeldung als Person statt mit dem Token, das alles darf. Das Token bleibt als
   Rückweg, bis die Anmeldung auf einem Gerät funktioniert hat.
3. App: die Anmeldung mit Passkey. Dafür fehlen die Team-ID des Apple-Entwicklerkontos und die
   Adresse des Dashboards (`apple-app-site-association`); prüfen lässt sie sich nur am Gerät.

## Was als Nächstes dran ist

Die Zeilen mit „fehlt“ sind echte Lücken und werden Seite für Seite geschlossen, zusammen mit
dem einheitlichen Seitenaufbau. Die Zeilen mit „bauartbedingt“ brauchen eine Entscheidung, ob
die Regel dort eine Ausnahme kennt: Anmeldung über Passkey gibt es nur im Browser, das Token im
Schlüsselbund nur in der App.
