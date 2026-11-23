# Arbeitsweise in diesem Repository

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
