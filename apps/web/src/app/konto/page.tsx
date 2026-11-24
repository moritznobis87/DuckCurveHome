import { redirect } from "next/navigation";

import { AreaShell } from "@/components/layout/AreaShell";
import { MeinZugang } from "@/components/zugang/MeinZugang";
import { ausweis, zustand } from "@/lib/zugang";

export const dynamic = "force-dynamic";
export const metadata = { title: "Mein Zugang · Duck Curve Home" };

/**
 * Der eigene Zugang: Passkeys, Passwort, Sitzungen, Abmelden.
 *
 * Die Seite steht außerhalb der sechs Bereiche (`docs/seitenbaum.json`, `einzelseiten`) und ist
 * für **jede angemeldete Person** da, nicht nur für den Hausherrn. Der Hausherr hat das am
 * 24.11.2026 entschieden: bis dahin stand der Abschnitt auf „Zugang und Sicherung“ im Bereich
 * System, und ein Bewohner konnte weder sein Passwort wechseln noch seine Passkeys pflegen noch
 * sich abmelden.
 *
 * Wer nicht angemeldet ist, geht zur Anmeldung. Ohne Person (Demo, API-Token) sagt die Seite,
 * dass es hier nichts Eigenes gibt; das entscheidet `MeinZugang`.
 */
export default async function Page() {
  const wer = await ausweis();
  if (wer === null) redirect("/anmeldung");
  const stand = await zustand();
  return (
    <AreaShell kicker="Passkeys · Passwort · Sitzungen">
      {/* Ohne eigene Überschrift: der Name der Seite steht schon im Kopf und in der Zeile darunter. */}
      <section className="flex max-w-[760px] flex-col gap-3" aria-label="Mein Zugang">
        <MeinZugang mindestlaenge={stand.passwort_mindestlaenge} />
      </section>
    </AreaShell>
  );
}
