import { AreaShell } from "@/components/layout/AreaShell";
import { Regelkreis } from "@/components/regelkreis/Regelkreis";
import { requireOwner } from "@/lib/guard";

// Ohne dies rendert Next die Seite beim Build vor, und requireOwner liefe nie zur Laufzeit.
export const dynamic = "force-dynamic";
export const metadata = { title: "Regelkreis · Duck Curve Home" };

export default async function Page() {
  // Wer hier einen Parameter übersteuert, greift in die Auslegung der Regler ein.
  await requireOwner();
  return (
    <AreaShell kicker="Die ganze Regelung als Blockschaltbild · und woher jede Zahl kommt">
      <Regelkreis />
    </AreaShell>
  );
}
