import { Anlage } from "@/components/anlage/Anlage";
import { AreaShell } from "@/components/layout/AreaShell";

export const dynamic = "force-dynamic";
export const metadata = { title: "Anlage · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Strom · Speicher · vier Kreise">
      <Anlage />
    </AreaShell>
  );
}
