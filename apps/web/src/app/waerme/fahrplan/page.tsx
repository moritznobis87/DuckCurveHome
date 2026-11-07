import { Fahrplan } from "@/components/waerme/Fahrplan";
import { AreaShell } from "@/components/layout/AreaShell";

export const dynamic = "force-dynamic";
export const metadata = { title: "Fahrplan · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Preis · PV · Wärmebedarf · Puffer · zwei Tage">
      <Fahrplan />
    </AreaShell>
  );
}
