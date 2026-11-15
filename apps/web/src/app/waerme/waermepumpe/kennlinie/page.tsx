import { AreaShell } from "@/components/layout/AreaShell";
import { Kennlinie } from "@/components/waermepumpe/Kennlinie";

export const dynamic = "force-dynamic";
export const metadata = { title: "Kennlinie der Wärmepumpe · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Arbeitszahl · gemessen">
      <Kennlinie />
    </AreaShell>
  );
}
