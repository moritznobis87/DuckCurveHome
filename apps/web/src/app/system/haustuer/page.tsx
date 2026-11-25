import { AreaShell } from "@/components/layout/AreaShell";
import { DoorLog } from "@/components/settings/DoorLog";

export const dynamic = "force-dynamic";
export const metadata = { title: "Haustür · Duck Curve Home" };

export default function Page() {
  return (
    <AreaShell kicker="Wer sich am Reader erkennen ließ, und was geschah">
      {/* Eine Karte wie auf den übrigen Systemseiten, ohne Erklärtexte (Hausherr, 25.11.2026). */}
      <div className="konto max-w-[820px]">
        <DoorLog />
      </div>
    </AreaShell>
  );
}
