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
| Berichte | „Die Anmeldung gilt nicht mehr. Bitte neu anmelden.“ | `components/reports/useReport.ts`, `YearMap.tsx` | bauartbedingt ein Halbsatz mehr: Die App nennt den Ort („Unter „Zugang und Sicherung“ neu anmelden“, `ApiFehler.rat`), weil sie keine eigene Anmeldeseite hat. |
| Zugang und Sicherung | Personen, Einladungslink, Passkeys, Sitzungen | `components/zugang/Personen.tsx`, `MeinZugang.tsx`, `app/system/zugang/page.tsx` | zum Teil: siehe den Abschnitt „Anmeldung“ unten |

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
| Startseite (seit dem 25.11.2026) | Der Puffer steht an der Wand als Glas in seiner Karte und liegt am Telefon. | Der Puffer liegt auch an der Wand: die Karte neben dem Bild ist für das stehende Glas der App zu niedrig. In der App ungesehen. | `components/home/Karten.tsx`, `Seiten/Jetzt/Startkarten.swift` |
| Startseite (seit dem 25.11.2026) | An der Wand stehen Tageskurve und Schalter in je einer Karte, die vier Zahlen des Tages im Kopf der Tageskarte. | Kurve, vier Zahlen und Schalter stehen an der Wand wie bisher ohne Karten in zwei Reihen. Der Inhalt ist derselbe. | `components/home/Home.tsx`, `Seiten/Jetzt/JetztSeite.swift` |
| Startseite (seit dem 25.11.2026) | Der Lüfter der Wärmepumpe dreht sich auf der Bühne, solange sie läuft. | Der Lüfter steht; die Bänder bewegen sich in beiden. | `components/home/Buehne.tsx`, `Seiten/Jetzt/Buehnenbild.swift` |
| Startseite | Ein Tipp auf den Speicher führt auf seine Seite. | Ein Tipp öffnet das Blatt des Speichers. Das war schon vor dem neuen Bild so. | `components/home/Buehne.tsx`, `Seiten/Jetzt/Buehnenbild.swift` |

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

**Gebaut am 24.11.2026:**

- Der Dienst (`dch_api/auth/passwort.py`, vier Endpunkte unter `/auth`).
- Im Dashboard: die Anmeldung mit E-Mail-Adresse und Passwort, die Wahl zwischen Passkey und
  Passwort hinter dem Einladungslink, „Mein Passwort“ unter „Zugang und Sicherung“.
- In der App: die Anmeldung mit E-Mail-Adresse und Passwort beim Einrichten (`Einrichten.swift`)
  und die Karte „Mein Passwort“ (`MeinPasswortKarte.swift`), mit den Sätzen des Dashboards
  (`Anmeldeworte.swift`). Die App spricht dann als Person und nicht mehr mit dem Token, das
  alles darf. Das Token bleibt als zweiter Weg für den, der den Dienst betreibt.
- Der Abschnitt „Wie man hereinkommt“ steht in der App jetzt im Wortlaut des Dashboards. Bis
  dahin beschrieb die App Kopplungslinks und ein Gast-Token, die es seit dem 23.11.2026 nicht
  mehr gibt.

**Entschieden und gebaut am 24.11.2026: die Seite „Mein Zugang“.** Der eigene Zugang steht
auf einer eigenen Seite außerhalb der sechs Bereiche (`/konto`, in `docs/seitenbaum.json` unter
`einzelseiten`), erreichbar über das Personenzeichen im Kopf, für jede angemeldete Person. Bis
dahin stand er auf „Zugang und Sicherung“ im Bereich System, den nur der Hausherr sieht: ein
Bewohner konnte weder sein Passwort wechseln noch sich abmelden (Fund im Review von PR 31).
Dabei behoben: Das Dashboard zeigte einem Bewohner das Zahnrad und die Seiten des Hausherrn,
die ihn dann zurückwarfen, weil die Leiste „darf stellen“ mit „hat Vollzugriff“ gleichsetzte.

**Behoben am 24.11.2026: die vier Rollen in der App.** Die App kannte zwei Stufen, und ein
Bewohner sah in ihr nur zu, obwohl der Dienst ihm das Stellen im Haus erlaubt. Jetzt trägt sie
die vier Rollen des Dienstes und fragt wie das Dashboard zweierlei: „darf stellen“ für die
Schalter im Haus (`Hauszustand.darfSchalten`), „hat Vollzugriff“ für Akten, System und
Abstimmen (`Hauszustand.hatVollzugriff`).

**Offen:**

| Was | Dashboard | App | Fundstelle |
|---|---|---|---|
| Anmeldung mit Passkey | vorhanden | fehlt. Sie braucht die Team-ID des Apple-Entwicklerkontos und die Adresse des Dashboards (`apple-app-site-association`) und lässt sich nur am Gerät prüfen. | `app/anmeldung/passkey.tsx`, `Einrichten.swift` |
| Einladungslink einlösen | Seite `/anmeldung/einrichten` | bauartbedingt im Browser: Der Link ist eine Adresse des Dashboards. | `app/anmeldung/einrichten/page.tsx` |
| Personen verwalten und einladen | vorhanden | fehlt | `components/zugang/Personen.tsx` |
| Eigene Passkeys, eigene Sitzungen, neue Wiederherstellungscodes | vorhanden auf „Mein Zugang“ | seit dem 24.11.2026 vorhanden: Passkeys umbenennen und löschen, neue Codes, Sitzungen beenden, überall abmelden, dazu dieselbe Kopfkarte. Es fehlt nur das Anlegen eines Passkeys; es braucht dieselbe Zuordnung wie die Anmeldung mit Passkey, und die Seite sagt, dass man ihn im Dashboard anlegt. | `components/zugang/MeinZugang.tsx`, `KontoSeite.swift` |
| Sitzung in der Liste erkennen | Ein Browser steht dort mit seinem Gerät („iPhone“, „Mac“). | Eine Sitzung der App steht dort als „unbekanntes Gerät“, weil die App keinen sprechenden User-Agent schickt. | `MeinZugang.tsx` (`geraet`), `Zugang.kopfzeilen` |
| Zeichen der Person im Kopf | Steht da, wenn eine Person angemeldet ist. Ohne Anmeldung gibt es im Browser nur die Anmeldeseite. | Steht seit dem 26.11.2026 immer da. Ein Gerät, das mit dem API-Token eingerichtet ist, hat keine Person; dort führt das Zeichen auf „Mein Zugang“ mit dem Knopf „Mit meinem Zugang anmelden“. Bauartbedingt: den Fall „verbunden, aber keine Person“ kennt nur die App. | `components/layout/AreaNav.tsx`, `App/Reiterzeile.swift`, `Seiten/KontoSeite.swift` |

## Übersichten (24.11.2026)

Rückmeldung des Hausherrn: Die Übersichten waren grafisch schwach und zu textlastig. Beide
zeigen jetzt Kacheln mit Zeichen, Farbe, großer Zahl und einem kleinen Bild (Tagesverlauf,
Füllstand, Abweichung, Fahrplan). Die Bilddaten liefert der Dienst (`UebersichtBildOut`); die
Rechnung davor steht im Dashboard in `Kachelbild.tsx` und in der App in `Kachelbild.swift`,
von je einem Test mit denselben Fällen gehalten.

## Was als Nächstes dran ist

Die Zeilen mit „fehlt“ sind echte Lücken und werden Seite für Seite geschlossen, zusammen mit
dem einheitlichen Seitenaufbau. Die Zeilen mit „bauartbedingt“ bleiben, solange der Grund
besteht, und stehen hier, damit sie niemand für ein Versehen hält.
