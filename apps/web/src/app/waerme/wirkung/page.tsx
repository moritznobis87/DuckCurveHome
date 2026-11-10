import { Wirkung } from "@/components/waerme/Wirkung";
import { AreaShell } from "@/components/layout/AreaShell";

export const dynamic = "force-dynamic";
export const metadata = { title: "Wirkung · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Folgt die Wärmepumpe der Anforderung? · gemessen, nicht angenommen">
      <Wirkung />
    </AreaShell>
  );
}
