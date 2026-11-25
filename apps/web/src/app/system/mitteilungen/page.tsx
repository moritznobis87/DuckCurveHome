import { requireOwner } from "@/lib/guard";
import { AreaShell } from "@/components/layout/AreaShell";
import { Mitteilungen } from "@/components/settings/Mitteilungen";
import { Morgenbrief } from "@/components/settings/Morgenbrief";

export const dynamic = "force-dynamic";
export const metadata = { title: "Mitteilungen · Duck Curve Home" };

export default async function Page() {
  await requireOwner();
  return (
    <AreaShell kicker="Was aufs Handy kommt: Störungen und das Morning Briefing">
      {/* Zwei Karten wie auf den übrigen Systemseiten, ohne Erklärtexte (Hausherr, 25.11.2026). */}
      <div className="konto max-w-[820px]">
        <Mitteilungen />
        <Morgenbrief />
      </div>
    </AreaShell>
  );
}
