/**
 * Ob die Oberfläche eine Anmeldung verlangt - **ohne Node-Bausteine**.
 *
 * Eigene Datei, weil die Middleware in der Edge-Laufzeit läuft: sie darf `node:crypto` nicht
 * sehen, und genau das importiert `lib/session.ts` für die Signatur des Gerätecookies. Ein
 * Import von dort hat den Bau zum Scheitern gebracht („Reading from node:crypto is not handled").
 *
 * Zwei Schalter, weil es zwei Dinge sind: `DCH_SESSION_SECRET` macht die **Gerätepaarung**
 * möglich (Wandanzeige, Gastlink) und verlangt damit auch eine Anmeldung. Ein Hausgerät, das
 * keine Geräte paart, sondern nur Personen kennt, setzt stattdessen `DCH_ANMELDUNG=1`. Ohne
 * beides ist die Anmeldung aus - Entwicklung und Demo, wie bisher.
 */
export function anmeldungNoetig(): boolean {
  const schalter = (process.env.DCH_ANMELDUNG ?? "").trim().toLowerCase();
  if (schalter === "0" || schalter === "aus" || schalter === "false") return false;
  const geraetepaarung = (process.env.DCH_SESSION_SECRET ?? "").length >= 32;
  return geraetepaarung || ["1", "an", "true"].includes(schalter);
}
