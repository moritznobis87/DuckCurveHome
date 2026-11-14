import { AreaShell } from "@/components/layout/AreaShell";
import { Waermepumpe } from "@/components/waermepumpe/Waermepumpe";

export const dynamic = "force-dynamic";
export const metadata = { title: "Wärmepumpe · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Außengerät · Innengerät · Speicher">
      <Waermepumpe />
    </AreaShell>
  );
}
