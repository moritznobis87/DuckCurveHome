import { AreaShell } from "@/components/layout/AreaShell";
import { Regler } from "@/components/waermepumpe/Regler";

export const dynamic = "force-dynamic";
export const metadata = { title: "Regler der Wärmepumpe · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Einstellungen · gelesen">
      <Regler />
    </AreaShell>
  );
}
