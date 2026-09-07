import { InvoiceCheck } from "@/components/reports/InvoiceCheck";
import { requireOwner } from "@/lib/guard";

// Ohne dies rendert Next die Seite beim Build vor - requireOwner liefe dann nie zur Laufzeit
// und ein Gast bekäme wenigstens das Gerüst der Seite ausgeliefert.
export const dynamic = "force-dynamic";

export const metadata = { title: "Rechnungsprüfung · Duck Curve Home" };

export default async function Page() {
  await requireOwner(); // Rechnungen enthalten Name, Adresse, Zählernummer und IBAN
  return <InvoiceCheck />;
}
