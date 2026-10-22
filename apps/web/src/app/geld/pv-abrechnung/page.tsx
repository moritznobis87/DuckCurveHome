import { PvAccounting } from "@/components/reports/PvAccounting";
import { requireOwner } from "@/lib/guard";
export const dynamic = "force-dynamic";
export const metadata = { title: "PV-Abrechnung · Duck Curve Home" };

export default async function Page() {
  await requireOwner();
  return <PvAccounting />;
}
