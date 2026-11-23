/**
 * Ob die Oberfläche eine Anmeldung verlangt - **ohne Node-Bausteine**.
 *
 * Eigene Datei, weil die Middleware in der Edge-Laufzeit läuft und dort kein `node:`-Modul sehen
 * darf.
 *
 * **Die Vorgabe ist „an".** Seit die Gerätepaarung weg ist (23.11.2026) gibt es keinen Schalter
 * mehr, der nebenbei die Anmeldung einschaltete - vorher war das `DCH_SESSION_SECRET`, das
 * eigentlich nur das Gerätecookie signierte. Eine Instanz, die die Variable vergisst, soll **zu**
 * sein und nicht offen; das ist die Richtung, in der ein Versehen harmlos bleibt.
 *
 * Ausgeschaltet wird ausdrücklich mit `DCH_ANMELDUNG=aus` - das tun `docker-compose.yml` und
 * `tools/demo.sh`, denn der Demo-Modus läuft ohne Datenbank und hat damit keine Personen, als die
 * sich jemand anmelden könnte.
 */
export function anmeldungNoetig(): boolean {
  const schalter = (process.env.DCH_ANMELDUNG ?? "").trim().toLowerCase();
  return !["0", "aus", "false", "nein", "off"].includes(schalter);
}
