import { requireOwner } from "@/lib/guard";
import { AreaShell } from "@/components/layout/AreaShell";
import { Mitteilungen } from "@/components/settings/Mitteilungen";

export const dynamic = "force-dynamic";
export const metadata = { title: "Mitteilungen · Duck Curve Home" };

export default async function Page() {
  await requireOwner();
  return (
    <AreaShell kicker="Wer erfährt es, wenn eine Quelle schweigt">
      <section className="flex max-w-[760px] flex-col gap-3">
        <h2 className="m-0 text-[18px] font-semibold">Mitteilungen</h2>
        <Mitteilungen />
      </section>
    </AreaShell>
  );
}
