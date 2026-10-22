import { requireOwner } from "@/lib/guard";

// Der ganze Bereich ist dem Hausherrn vorbehalten: Prognoseguete und Datenpruefung waren Gaesten
// offen, Haustuer und Zugang nie. Eine Grenze je Bereich ist leichter zu pruefen als eine je Seite.
export const dynamic = "force-dynamic";

export default async function SystemLayout({ children }: { children: React.ReactNode }) {
  await requireOwner();
  return children;
}
