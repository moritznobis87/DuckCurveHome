import { Einstellen } from "@/components/einstellen/Einstellen";
import { AreaShell } from "@/components/layout/AreaShell";
import { requireRolle } from "@/lib/guard";

export const dynamic = "force-dynamic";
export const metadata = { title: "Einstellen · Duck Curve Home" };

/**
 * Hinter dem Zahnrad. Wer im Haus stellen darf, sieht sie: Hausherr und Bewohner. Ein Gast und
 * der Beratungszugang stellen im Haus nichts und haben hier nichts zu finden.
 */
export default async function Page() {
  await requireRolle("hausherr", "bewohner");
  return (
    <AreaShell kicker="was von Hand gestellt ist · eingreifen · vorgeben · abstimmen">
      <Einstellen />
    </AreaShell>
  );
}
