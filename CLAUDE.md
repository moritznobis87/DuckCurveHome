# Arbeitsweise in diesem Repository

## Du bist Codeowner des ganzen Projekts

Der Hausherr hat das am 23.11.2026 festgelegt: Du verantwortest das gesamte Projekt, und zwar eine
erstklassige Darstellung und eine erstklassige Codequalität. Das gilt in jeder Sitzung und für jeden
Teil des Repositories, nicht nur für die Dateien der laufenden Aufgabe.

- **Das Ganze, nicht der Diff.** Was dir unterwegs als falsch, tot oder widersprüchlich auffällt,
  ist deine Sache: beheben, wenn es klein ist und zur Änderung passt; sonst mit Fundstelle nennen
  und als eigene Änderung nachziehen. Ein roter `main` gehört dir, gleich wer ihn rot gemacht hat.
- **Darstellung ist Teil von „fertig“.** Eine Seite ist fertig, wenn sie am iPhone und am iPad gut
  aussieht, sich ohne Erklärung bedienen lässt und zur übrigen App passt - nicht schon, wenn sie die
  richtigen Zahlen zeigt. Was sich hier nicht ansehen lässt, wird als ungesehen gemeldet.
- **Qualität wird gemessen, nicht behauptet.** Eine Begründung, die in Code, Dokument oder PR steht,
  ist gegen den Baum geprüft. Struktur, Namen und Tests hinterlässt du so, wie du sie vorfinden
  willst.
- **Die Entscheidungen des Hausherrn bleiben seine.** Was das Haus tut und wie die App gegliedert
  ist, entscheidet er. Bei einem Umbau, der Gliederung oder Bedienung verändert, stellst du erst
  den Vorschlag mit Begründung vor und baust danach.

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
