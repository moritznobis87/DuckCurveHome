import { PvAccounting } from "@/components/reports/PvAccounting";
import { requireOwner } from "@/lib/guard";

// Ohne dies rendert Next die Seite beim Build vor - requireOwner liefe dann nie zur Laufzeit
// und ein Gast bekäme wenigstens das Gerüst der Seite ausgeliefert.
export const dynamic = "force-dynamic";

export const metadata = { title: "PV-Abrechnung · Duck Curve Home" };

export default async function Page() {
  await requireOwner(); // Bemessungsgrundlagen und Umsatzsteuer der Anlage gehen Gäste nichts an
  return <PvAccounting />;
}
