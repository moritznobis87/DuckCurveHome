import { AreaShell } from "@/components/layout/AreaShell";
import { Geraet } from "@/components/geraet/Geraet";

export const dynamic = "force-dynamic";
export const metadata = { title: "Hausgerät · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Dienste, Gesundheit, Sicherung und Updates des Rechners im Haus">
      <Geraet />
    </AreaShell>
  );
}
