import { requireRolle } from "@/lib/guard";

// Der ganze Bereich bleibt dem Hausherrn vorbehalten - mit einer Ausnahme: der Beratungszugang
// (`service`) darf hierher, weil hier die Seite „Hausgerät" liegt, an der er arbeitet. Die Seiten
// mit den Akten (Zugang, Mitteilungen, Haustür) prüfen zusätzlich selbst, und der Dienst lässt
// einen Beratungszugang auch bei Kenntnis der Adresse nicht an sie heran
// (dch_api/auth/rechte.py).
export const dynamic = "force-dynamic";

export default async function SystemLayout({ children }: { children: React.ReactNode }) {
  await requireRolle("hausherr", "service");
  return children;
}
