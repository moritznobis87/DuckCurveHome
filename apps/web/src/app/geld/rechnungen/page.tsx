import { InvoiceCheck } from "@/components/reports/InvoiceCheck";
import { requireOwner } from "@/lib/guard";
export const dynamic = "force-dynamic";
export const metadata = { title: "Rechnungsprüfung · Duck Curve Home" };

export default async function Page() {
  await requireOwner();
  return <InvoiceCheck />;
}
