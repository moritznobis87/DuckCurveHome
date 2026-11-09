import { Wiedergabe } from "@/components/waerme/Wiedergabe";
import { AreaShell } from "@/components/layout/AreaShell";

export const dynamic = "force-dynamic";
export const metadata = { title: "Wiedergabe · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Ein Tag am Anlagenschema · zum Durchfahren">
      <Wiedergabe />
    </AreaShell>
  );
}
