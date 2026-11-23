import { redirect } from "next/navigation";

import { ausweis, type Rolle } from "@/lib/zugang";

/**
 * Seiten, die nicht jeder sehen soll. Serverseitig, damit sie gar nicht erst ausgeliefert werden -
 * die Daten dahinter sperrt zwar auch der Dienst, aber eine Seite, die nur Fehlermeldungen zeigt,
 * ist keine gute Antwort auf „das darfst du nicht".
 *
 * Die Wahrheit über Rechte steht in `dch_api/auth/rechte.py`. Hier geht es nur darum, niemanden
 * vor eine Seite zu setzen, die ihm nichts zeigen kann.
 */

/** Nur mit Vollzugriff: die Akten des Hauses und die Verwaltung. */
export async function requireOwner(): Promise<void> {
  await requireRolle("hausherr");
}

/** Eine der genannten Rollen - sonst zurück auf die Startseite. */
export async function requireRolle(...erlaubt: Rolle[]): Promise<void> {
  const wer = await ausweis();
  if (wer === null) redirect("/anmeldung");
  if (!erlaubt.includes(wer.rolle)) redirect("/");
}
