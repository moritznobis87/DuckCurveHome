import { InvoiceCheck } from "@/components/reports/InvoiceCheck";
import { requireOwner } from "@/lib/guard";

export const metadata = { title: "Rechnungsprüfung · Duck Curve Home" };

export default async function Page() {
  await requireOwner(); // Rechnungen enthalten Name, Adresse, Zählernummer und IBAN
  return <InvoiceCheck />;
}
