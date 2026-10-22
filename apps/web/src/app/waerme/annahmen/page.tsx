import Link from "next/link";
import { AreaShell } from "@/components/layout/AreaShell";
import { HeatSettings } from "@/components/settings/HeatSettings";
import { requireOwner } from "@/lib/guard";

// Ohne dies rendert Next die Seite beim Build vor, und requireOwner liefe nie zur Laufzeit.
export const dynamic = "force-dynamic";
export const metadata = { title: "Annahmen der Wärmerechnung · Duck Curve Home" };

export default async function Page() {
  await requireOwner(); // Wer die Annahmen aendert, aendert jede Auswertung rueckwirkend
  return (
    <AreaShell kicker="Lieferschein · Datenblatt · Puffer">
      <section className="flex max-w-[980px] flex-col gap-3">
        <p className="m-0 text-[15px] leading-[1.6] text-text-2">
          Es gibt keinen Wärmemengenzähler im Haus. Die Wärmebilanz wird deshalb gerechnet, und diese
          Zahlen sind die Annahmen dahinter: was auf dem Lieferschein der Pellets steht, was im
          Datenblatt des Ofens steht, wie warm der Puffer gefahren wird. Jede Änderung wirkt sofort
          und rückwirkend, weil Messwerte gespeichert sind und keine Rechenergebnisse.
        </p>
        <HeatSettings />
        <p className="m-0 text-[14px] leading-[1.6] text-text-3">
          Ob die Zahlen stimmen, steht auf der <Link href="/waerme/bilanz" className="text-amber">Wärmebilanz</Link>:
          dort gibt es die Zeile „nicht zuzuordnen". Was die Erzeuger nicht erklären, landet in ihr,
          und sie klein zu bekommen ist genau der Sinn dieser Felder.
        </p>
      </section>
    </AreaShell>
  );
}
