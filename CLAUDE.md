# Arbeitsweise in diesem Repository

## Du bist Codeowner des ganzen Projekts

Der Hausherr hat das am 23.11.2026 festgelegt: Du verantwortest das gesamte Projekt, und zwar eine
erstklassige Darstellung und eine erstklassige Codequalität. Das gilt in jeder Sitzung und für jeden
Teil des Repositories, nicht nur für die Dateien der laufenden Aufgabe.

- **Das Ganze, nicht der Diff.** Was dir unterwegs als falsch, tot oder widersprüchlich auffällt,
  ist deine Sache: beheben, wenn es klein ist und zur Änderung passt; sonst mit Fundstelle nennen
  und als eigene Änderung nachziehen. Ein roter `main` gehört dir, gleich wer ihn rot gemacht hat.
- **Darstellung ist Teil von „fertig“.** Eine Seite ist fertig, wenn sie am iPhone, am iPad und im
  Browser gut aussieht, sich ohne Erklärung bedienen lässt und zur übrigen App passt - nicht schon, wenn sie die
  richtigen Zahlen zeigt. Was sich hier nicht ansehen lässt, wird als ungesehen gemeldet.
- **Texte in der Oberfläche sind ausformuliert.** Kein Gedankenstrich, an dem ein paar Wörter
  hängen, und keine Stichwortketten, wo ein Satz hingehört: das liest sich wie von einer Maschine
  geschrieben. Jeder Satz steht so da, wie ihn ein Fachmann einem Kunden schreiben würde.
- **Qualität wird gemessen, nicht behauptet.** Eine Begründung, die in Code, Dokument oder PR steht,
  ist gegen den Baum geprüft. Struktur, Namen und Tests hinterlässt du so, wie du sie vorfinden
  willst.
- **Die Entscheidungen des Hausherrn bleiben seine.** Was das Haus tut und wie die App gegliedert
  ist, entscheidet er. Bei einem Umbau, der Gliederung oder Bedienung verändert, stellst du erst
  den Vorschlag mit Begründung vor und baust danach.

## Dashboard und App sind dasselbe, zweimal

Der Hausherr hat das am 23.11.2026 festgelegt: Das Dashboard (`apps/web`) und die App (`apps/ios`)
bestehen dauerhaft nebeneinander und zeigen identische Inhalte. Keines ersetzt das andere, und
keines ist nur Vorlage für das andere.

- **Jede Änderung an Inhalt, Gliederung oder Bedienung kommt in beide, im selben Pull Request.**
  Seiten, Adressen, Namen, Zahlen, Texte und Einstellmöglichkeiten sind gleich. Fertig, wenn beide
  dasselbe zeigen und für beide die Prüfungen aus der PR-Regel grün sind.
- **Die Anordnung darf der Bildschirmbreite folgen, der Inhalt nicht.** Dieselbe Seite schmal und
  breit anders zu setzen ist kein Unterschied. Ein Wert, ein Satz oder ein Schalter, den nur eines
  von beiden hat, ist einer.
- **Ein Unterschied, den du findest, ist ein Fehler.** Beheben oder mit Fundstelle nennen, wie
  unter „Codeowner“ beschrieben.
- **Der Seitenbaum steht einmal in `docs/seitenbaum.json`.** Dashboard und App werden je mit einem
  Test dagegen gehalten (`seitenbaum.test.ts`, `SeitenbaumTests.swift`). Wer Gliederung, Namen
  oder Adressen ändert, ändert zuerst diese Datei und zieht dann beide nach.

## Arbeit muss einen Abbruch überstehen

Der Hausherr hat das am 24.11.2026 festgelegt. Am Tag davor brach eine Bestandsaufnahme mit neun
parallelen Prüfern am Nutzungslimit ab; sie hatte rund 640 000 Tokens verbraucht und keinen
einzigen Bericht hinterlassen.

- **Nichts starten, das nur als Ganzes etwas wert ist.** Eine Arbeit wird so geschnitten, dass
  jeder Teil für sich ein fertiges Ergebnis hinterlässt, das wichtigste zuerst. Fertig heißt:
  bricht die Sitzung nach diesem Teil ab, ist er trotzdem zu gebrauchen.
- **Zwischenstände laufend sichern.** Wer misst oder untersucht, schreibt jeden Fund sofort in
  eine Datei und nicht erst am Ende in einen Bericht. Was Bestand haben soll, liegt im Repository
  auf dem Arbeitszweig und ist gepusht. Im Scratchpad liegt nur, was verloren gehen darf.
- **Erst das Billige, und mehrere Agenten nur auf Verlangen.** Vor jedem größeren Lauf selbst
  nachsehen, was sich mit wenigen Aufrufen klären lässt. Ein Lauf mit mehreren Prüfern oder
  Agenten startet nur, wenn der Hausherr ihn ausdrücklich verlangt, und dann in kleinen Losen:
  höchstens zwei zugleich, jedes Los mit eigenem abgelegtem Ergebnis, bevor das nächste beginnt.

## Neuerungen schreiben, Versionen bündeln

Der Hausherr hat das am 26.11.2026 festgelegt: Was ein Update bringt, lesen auch Außenstehende.
Darum stehen die Neuerungen nicht als Commit-Titel da, sondern je Bereich als ausformulierter
Satz in `docs/versionen.json`, und Versionen heißen nach Jahr, Monat und laufender Nummer
(`2026.11.1`), nicht nach einem Hash.

- **Jeder PR mit einer Wirkung, die Nutzer bemerken, trägt seine Sätze unter
  `unveroeffentlicht` ein.** Ein Satz sagt, was sich für den Nutzer ändert, nicht wie es gebaut
  ist: keine Dateinamen, Hashes, PR-Nummern oder Begriffe aus der Entwicklung.
  `tools/version.py --pruefen` hält das fest und läuft in der CI.
- **Eine Version entsteht gebündelt und nur auf Wunsch des Hausherrn**, oder wenn du sie nach
  einer abgeschlossenen Arbeit vorschlägst und er zustimmt: `tools/version.py --veroeffentlichen`
  im eigenen PR. Nach dem Merge baut die CI die Images, setzt das Tag `v<version>`, legt die
  Veröffentlichung auf GitHub an und gibt sie im Kanal `stabil` an die Hausgeräte.

## Jede Änderung geht über einen Pull Request nach `main`

Der Hausherr hat das am 23.11.2026 festgelegt. Es gilt für jede Änderung, auch eine kleine, und
ersetzt die Rückfrage, ob ein PR angelegt oder gemergt werden soll.

1. **Den Zweig auf `main` aufsetzen.** `main` holen und, wenn der Zweig dahinter liegt, hineinmergen.
   Fertig, wenn `git log HEAD..origin/main` leer ist.
2. **Lokal prüfen, was die CI prüft**, für jeden berührten Teil: die Befehle unter „Entwicklung“ in
   `README.md`, für `apps/ios` dazu `tools/ios-pruefen.sh`. Fertig, wenn alles, was hier laufen
   kann, grün ist.
3. **Pushen und den PR gegen `main` öffnen.** Die Beschreibung sagt, was sich ändert, was geprüft
   ist und was nicht.
4. **Den PR durchziehen.** Am PR bleiben, bis die CI durch ist (in Cloud-Sitzungen über
   `subscribe_pr_activity`), und jeden offenen Punkt erledigen: rote CI an ihrer Ursache beheben,
   einen Konflikt durch Hineinmergen von `main` lösen, jeden Review-Fund prüfen, auch die des
   Codex-Bots, und ihn beheben oder begründet beantworten. Fertig, wenn am aktuellen Kopf alle
   Check-Runs grün sind, kein Konflikt besteht und kein Review-Thread offen ist.
5. **Selbst mergen**, mit einem Merge-Commit und ohne Rückfrage. Danach dem Hausherrn den Link zum
   PR nennen.

Grün wird die CI nur durch eine Behebung; Tests bleiben dabei eingeschaltet. Liegt die Ursache
außerhalb des PRs oder braucht ein Fund eine Entscheidung des Hausherrn, bleibt der PR offen, und
die Sitzung sagt, was blockiert und was sie braucht.
